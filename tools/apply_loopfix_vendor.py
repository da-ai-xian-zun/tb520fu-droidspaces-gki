#!/usr/bin/env python3
"""Apply mount.c loop-scan changes on upstream 76cbd21 (LF only)."""
from pathlib import Path

V = Path(__file__).resolve().parents[1] / "vendor" / "Droidspaces-OSS"
mount_c = V / "src" / "mount.c"
text = mount_c.read_text(encoding="utf-8")

old_open = """/*
 * Resolve loop device node path after LOOP_CTL_GET_FREE.
 *
 * Android userspace (vold): /dev/block/loopN
 * Android recovery + desktop Linux: /dev/loopN
 *
 * Strategy: probe the environment-preferred path with retries for ueventd/udev,
 * cross-try the other path, then mknod as a last resort (major 7, minor=devnr).
 */
static int open_loop_dev(long devnr, char *path_out, size_t path_size) {"""

new_open = """/*
 * Android: APEX may occupy low loop minors; LOOP_CTL_GET_FREE can return busy slots.
 * Fallback: scan upper pool minors when attaching rootfs images.
 */

static long scan_block_loop_max(void) {
  long max = 0;
  DIR *d = opendir("/sys/block");
  if (!d)
    return 0;
  struct dirent *de;
  while ((de = readdir(d)) != NULL) {
    if (strncmp(de->d_name, "loop", 4) != 0)
      continue;
    char *end;
    long n = strtol(de->d_name + 4, &end, 10);
    if (end != de->d_name + 4 && *end == '\\0' && n >= 0 && n > max)
      max = n;
  }
  closedir(d);
  return max;
}

static long read_max_loop(void) {
  long max_loop = 64;
  FILE *f = fopen("/sys/module/loop/parameters/max_loop", "r");
  if (f) {
    if (fscanf(f, "%ld", &max_loop) != 1 || max_loop <= 0)
      max_loop = 64;
    fclose(f);
  }
  /* sysfs max_loop may be lower than existing /sys/block/loopN nodes */
  if (is_android()) {
    long block_max = scan_block_loop_max();
    if (block_max + 1 > max_loop)
      max_loop = block_max + 1;
  }
  return max_loop;
}

/*
 * First minor to scan: skip lowest max(16, max_loop/4) slots (APEX uses low minors).
 * Relative to pool size — not an OEM-specific constant.
 */
static long loop_scan_start(long max_loop) {
  long skip = max_loop / 4;
  if (skip < 16)
    skip = 16;
  if (skip > max_loop)
    skip = max_loop;
  long start = max_loop - skip;
  return start > 0 ? start : 0;
}

static long loop_scan_used_max(void) {
  FILE *f = fopen("/proc/loops", "r");
  if (!f)
    return 0;
  char line[256];
  if (!fgets(line, sizeof(line), f)) {
    fclose(f);
    return 0;
  }
  long used_max = 0;
  while (fgets(line, sizeof(line), f)) {
    long dev = -1;
    if (sscanf(line, "%*s %ld", &dev) == 1 && dev > used_max)
      used_max = dev;
  }
  fclose(f);
  return used_max;
}

static int loop_status_fd(long devnr) {
  char path[64];
  if (is_android())
    snprintf(path, sizeof(path), "/dev/block/loop%ld", devnr);
  else
    snprintf(path, sizeof(path), "/dev/loop%ld", devnr);

  int fd = open(path, O_RDWR | O_CLOEXEC);
  if (fd < 0) {
    if (is_android())
      snprintf(path, sizeof(path), "/dev/loop%ld", devnr);
    else
      snprintf(path, sizeof(path), "/dev/block/loop%ld", devnr);
    fd = open(path, O_RDWR | O_CLOEXEC);
  }
  return fd;
}

static int loop_is_free(long devnr) {
  int fd = loop_status_fd(devnr);
  if (fd < 0)
    return 0;

  struct loop_info64 li;
  int ret = ioctl(fd, LOOP_GET_STATUS64, &li);
  int err = errno;
  close(fd);
  return (ret < 0 && err == ENXIO);
}

static long loop_find_free_devnr(void) {
  int ctl_fd = open("/dev/loop-control", O_RDWR | O_CLOEXEC);
  if (ctl_fd < 0) {
    ds_error("open /dev/loop-control: %s", strerror(errno));
    return -1;
  }
  long devnr = ioctl(ctl_fd, LOOP_CTL_GET_FREE);
  close(ctl_fd);
  if (devnr < 0)
    ds_error("LOOP_CTL_GET_FREE: %s", strerror(errno));
  return devnr;
}

/*
 * Resolve loop device node path for a specific minor.
 *
 * Android userspace (vold): /dev/block/loopN
 * Android recovery + desktop Linux: /dev/loopN
 *
 * Strategy: probe the environment-preferred path with retries for ueventd/udev,
 * cross-try the other path, then mknod as a last resort (major 7, minor=devnr).
 */
static int open_loop_dev(long devnr, char *path_out, size_t path_size) {"""

old_attach = """/*
 * Attach img_path to a free loop device via ioctls.
 * Sets LO_FLAGS_AUTOCLEAR so the kernel auto-releases the loop after umount.
 * Returns the open loop_fd on success (caller must close after mount()).
 * loop_path_out is filled with the device node path for the mount() call.
 */
static int loop_attach(const char *img_path, char *loop_path_out,
                       size_t path_size) {
  int ctl_fd = open("/dev/loop-control", O_RDWR | O_CLOEXEC);
  if (ctl_fd < 0) {
    ds_error("open /dev/loop-control: %s", strerror(errno));
    return -1;
  }

  long devnr = ioctl(ctl_fd, LOOP_CTL_GET_FREE);
  close(ctl_fd);
  if (devnr < 0) {
    ds_error("LOOP_CTL_GET_FREE: %s", strerror(errno));
    return -1;
  }

  int loop_fd = open_loop_dev(devnr, loop_path_out, path_size);
  if (loop_fd < 0) {
    ds_error("Failed to open loop%ld: %s", devnr, strerror(errno));
    return -1;
  }

  int img_fd = open(img_path, O_RDWR | O_CLOEXEC);
  if (img_fd < 0) {
    ds_error("open image %s: %s", img_path, strerror(errno));
    close(loop_fd);
    return -1;
  }

  if (ioctl(loop_fd, LOOP_SET_FD, img_fd) < 0) {
    ds_error("LOOP_SET_FD: %s", strerror(errno));
    close(img_fd);
    close(loop_fd);
    return -1;
  }
  close(img_fd); /* kernel holds a ref; we're done with this fd */

  struct loop_info64 li;
  memset(&li, 0, sizeof(li));
  /* AUTOCLEAR: kernel auto-releases loop device after umount + all fds closed
   */
  li.lo_flags = LO_FLAGS_AUTOCLEAR;
  snprintf((char *)li.lo_file_name, LO_NAME_SIZE, "%.63s", img_path);

  if (ioctl(loop_fd, LOOP_SET_STATUS64, &li) < 0)
    ds_warn("LOOP_SET_STATUS64: %s (continuing)", strerror(errno));

  return loop_fd;
}"""

new_attach = """static int loop_attach_one(long devnr, int img_fd, const char *img_path,
                           char *loop_path_out, size_t path_size) {
  int loop_fd = open_loop_dev(devnr, loop_path_out, path_size);
  if (loop_fd < 0) {
    ds_warn("Failed to open loop%ld: %s", devnr, strerror(errno));
    return -1;
  }

  if (ioctl(loop_fd, LOOP_SET_FD, img_fd) < 0) {
    int err = errno;
    if (err == EBUSY) {
      ioctl(loop_fd, LOOP_CLR_FD, 0);
      if (ioctl(loop_fd, LOOP_SET_FD, img_fd) == 0)
        goto set_status;
    }
    ds_warn("LOOP_SET_FD on loop%ld: %s", devnr, strerror(err));
    close(loop_fd);
    return -1;
  }

set_status:

  struct loop_info64 li;
  memset(&li, 0, sizeof(li));
  li.lo_flags = LO_FLAGS_AUTOCLEAR;
  snprintf((char *)li.lo_file_name, LO_NAME_SIZE, "%.63s", img_path);

  if (ioctl(loop_fd, LOOP_SET_STATUS64, &li) < 0)
    ds_warn("LOOP_SET_STATUS64: %s (continuing)", strerror(errno));

  return loop_fd;
}

/*
 * Attach img_path to a free loop device via ioctls.
 * Android: scan high minors first; desktop: LOOP_CTL_GET_FREE.
 */
static int loop_attach(const char *img_path, char *loop_path_out,
                       size_t path_size) {
  int img_fd = open(img_path, O_RDWR | O_CLOEXEC);
  if (img_fd < 0) {
    ds_error("open image %s: %s", img_path, strerror(errno));
    return -1;
  }

  int loop_fd = -1;

  if (is_android()) {
    long max_loop = read_max_loop();
    long start = loop_scan_start(max_loop);
    long used_max = loop_scan_used_max();
    if (used_max >= start)
      start = used_max + 1;
    if (start >= max_loop)
      start = max_loop > 0 ? max_loop - 1 : 0;

    for (long i = max_loop - 1; i >= start; i--) {
      if (!loop_is_free(i))
        continue;
      loop_fd = loop_attach_one(i, img_fd, img_path, loop_path_out, path_size);
      if (loop_fd >= 0)
        break;
    }
    if (loop_fd < 0) {
      for (long i = start - 1; i >= 0; i--) {
        if (!loop_is_free(i))
          continue;
        loop_fd =
            loop_attach_one(i, img_fd, img_path, loop_path_out, path_size);
        if (loop_fd >= 0)
          break;
      }
    }
  } else {
    long devnr = loop_find_free_devnr();
    if (devnr >= 0)
      loop_fd =
          loop_attach_one(devnr, img_fd, img_path, loop_path_out, path_size);
  }

  close(img_fd);

  if (loop_fd < 0)
    ds_error("Failed to attach %s to any free loop device", img_path);

  return loop_fd;
}"""

if old_open not in text:
    raise SystemExit("mount.c: open_loop_dev anchor missing")
if old_attach not in text:
    raise SystemExit("mount.c: loop_attach anchor missing")

text = text.replace(old_open, new_open, 1).replace(old_attach, new_attach, 1)
mount_c.write_text(text, encoding="utf-8", newline="\n")
print("[+] mount.c")

sparsemgr = V / "Android" / "app" / "src" / "main" / "assets" / "sparsemgr.sh"
st = sparsemgr.read_text(encoding="utf-8")
mount_loop_fn = Path(__file__).resolve().parents[1].joinpath(
    "patches", "sparsemgr_mount_loop_img.sh"
)
if not mount_loop_fn.is_file():
    raise SystemExit(f"missing {mount_loop_fn}")
insert = mount_loop_fn.read_text(encoding="utf-8").rstrip() + "\n\n"
anchor = "# umount wrapper\n_umount() {"
if anchor not in st:
    raise SystemExit("sparsemgr.sh: umount anchor missing")
st = st.replace(anchor, insert + anchor, 1)
st = st.replace(
    '    if ! _mount -t ext4 -o loop,rw,noatime,nodiratime,data=ordered,commit=30 \\\n'
    '            "$ROOTFS_IMG" "$ROOTFS_SPARSE"; then',
    '    if ! _mount_loop_img "$ROOTFS_IMG" "$ROOTFS_SPARSE" \\\n'
    '            rw,noatime,nodiratime,data=ordered,commit=30; then',
    1,
)
st = st.replace(
    '    if _mount -t ext4 -o loop,ro "$RESIZE_IMG" "$verify_dir" 2>/dev/null; then',
    '    if _mount_loop_img "$RESIZE_IMG" "$verify_dir" ro 2>/dev/null; then',
    1,
)
sparsemgr.write_text(st, encoding="utf-8", newline="\n")
print("[+] sparsemgr.sh")

# mount_loop_scan.sh asset
mls_src = Path(__file__).resolve().parents[1] / "patches" / "mount_loop_scan.sh"
mls_dst = V / "Android" / "app" / "src" / "main" / "assets" / "mount_loop_scan.sh"
mls_dst.write_text(mls_src.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
print("[+] mount_loop_scan.sh")

installer = V / "Android" / "app" / "src" / "main" / "java" / "com" / "droidspaces" / "app" / "util" / "SparseImageInstaller.kt"
kt = installer.read_text(encoding="utf-8")

old_mount = """            // 4. Mount Image (Minimal options for Max compatibility)
            logger.i("[SPARSE] Mounting sparse image (Minimal loop,rw)...")
            val mountOptions = "loop,rw,nodelalloc,noatime,nodiratime,init_itable=0"
            val mountCmd = "${Constants.BUSYBOX_BINARY_PATH} mount -t ext4 -o $mountOptions \\"$imgPath\\" \\"$mountPoint\\" || " +
                          "mount -t ext4 -o $mountOptions \\"$imgPath\\" \\"$mountPoint\\""

            runRootCommand(mountCmd, logger) ?: throw Exception("Failed to mount sparse image. Your kernel might not support loop mounts here.")

            try {
                // 5. Extract Tarball
                logger.i("[SPARSE] Extracting tarball to mount point...")
                val isXz = tarball.name.lowercase().endsWith(".xz")
                val extractCmd = if (isXz) {
                    "cd \\"$mountPoint\\" && ${Constants.BUSYBOX_BINARY_PATH} xzcat \\"${tarball.absolutePath}\\" | ${Constants.BUSYBOX_BINARY_PATH} tar -xpf - 2>&1"
                } else {
                    "cd \\"$mountPoint\\" && ${Constants.BUSYBOX_BINARY_PATH} tar -xzpf \\"${tarball.absolutePath}\\" 2>&1"
                }

                // For extraction, we stream the output to the logger's debug level
                val extractResult = Shell.cmd(extractCmd).exec()
                if (!extractResult.isSuccess) {
                    throw Exception("Tarball extraction failed: ${extractResult.err.joinToString("\\n")}")
                }
                logger.i("[SPARSE] Extraction completed successfully")

                // 6. Apply Post-Extraction Fixes (using script as requested)
                applyScriptFixes(context, mountPoint, logger)

            } finally {
                // 7. Unmount (Always attempt)
                logger.i("[SPARSE] Unmounting sparse image...")
                Shell.cmd("${Constants.BUSYBOX_BINARY_PATH} sync").exec()
                delay(1000)

                val umountCmd = "${Constants.BUSYBOX_BINARY_PATH} umount -l \\"$mountPoint\\" || umount -l \\"$mountPoint\\""
                Shell.cmd(umountCmd).exec()

                // Cleanup mount point directory
                Shell.cmd("rmdir \\"$mountPoint\\"").exec()
            }

        } catch (e: Exception) {
            logger.e("[SPARSE] Error: ${e.message}")
            // Cleanup incomplete image on failure
            Shell.cmd("rm -f \\"$imgPath\\"").exec()
            throw e
        }
    }

    /**
     * Runs a root command and logs output. Returns result if successful, null otherwise.
     */"""

new_mount = """            // 4. Mount Image - upstream busybox mount -o loop first; loop-scan fallback on failure
            logger.i("[SPARSE] Mounting sparse image (busybox loop,rw; loop-scan fallback)...")
            val mountOptions = "rw,nodelalloc,noatime,nodiratime,init_itable=0"
            val mountScript = prepareAssetScript(context, "mount_loop_scan.sh", logger)
            val mountCmd = "BUSYBOX_PATH=${Constants.BUSYBOX_BINARY_PATH} \\"${mountScript.absolutePath}\\" \\"$imgPath\\" \\"$mountPoint\\" \\"$mountOptions\\""
            runRootCommand(mountCmd, logger) ?: throw Exception("Failed to mount sparse image. Your kernel might not support loop mounts here.")

            // 5. Extract Tarball (large xz rootfs may take 5-15 minutes)
            logger.i("[SPARSE] Extracting tarball to mount point (may take 5-15 min for large images)...")
            val isXz = tarball.name.lowercase().endsWith(".xz")
            val extractCmd = if (isXz) {
                "cd \\"$mountPoint\\" && ${Constants.BUSYBOX_BINARY_PATH} xzcat \\"${tarball.absolutePath}\\" | ${Constants.BUSYBOX_BINARY_PATH} tar -xpf - 2>&1"
            } else {
                "cd \\"$mountPoint\\" && ${Constants.BUSYBOX_BINARY_PATH} tar -xzpf \\"${tarball.absolutePath}\\" 2>&1"
            }

            val extractResult = Shell.cmd(extractCmd).exec()
            if (!extractResult.isSuccess) {
                throw Exception("Tarball extraction failed: ${extractResult.err.joinToString("\\n")}")
            }
            logger.i("[SPARSE] Extraction completed successfully")

            // 6. Apply Post-Extraction Fixes (using script as requested)
            applyScriptFixes(context, mountPoint, logger)

        } catch (e: Exception) {
            logger.e("[SPARSE] Error: ${e.message}")
            unmountSparseImage(mountPoint, imgPath, logger)
            Shell.cmd("rm -f \\"$imgPath\\"").exec()
            throw e
        }
    }

    /**
     * Unmount sparse image after container.config is written (success path).
     * Caller must invoke this; extract() leaves the mount active on success.
     */
    suspend fun unmountSparseImage(
        mountPoint: String,
        imgPath: String,
        logger: ContainerLogger
    ) = withContext(Dispatchers.IO) {
        logger.i("[SPARSE] Unmounting sparse image...")
        val umountCmd = "${Constants.BUSYBOX_BINARY_PATH} umount -l \\"$mountPoint\\" || umount -l \\"$mountPoint\\""
        Shell.cmd(umountCmd).exec()
        Shell.cmd(buildLoopDetachCmd(imgPath)).exec()
        Shell.cmd("rmdir \\"$mountPoint\\"").exec()
    }

    private suspend fun prepareAssetScript(
        context: Context,
        assetName: String,
        logger: ContainerLogger
    ): File {
        val out = File(context.cacheDir, assetName)
        context.assets.open(assetName).use { input ->
            FileOutputStream(out).use { output -> input.copyTo(output) }
        }
        Shell.cmd("chmod 755 \\"${out.absolutePath}\\"").exec()
        logger.d("[SPARSE] Prepared $assetName at ${out.absolutePath}")
        return out
    }

    private fun buildLoopDetachCmd(imgPath: String): String {
        return "losetup -a 2>/dev/null | grep -F \\"$imgPath\\" | sed -n 's/:.*//p' | while read dev; do losetup -d \\"\\$dev\\" 2>/dev/null; done"
    }

    /**
     * Runs a root command and logs output. Returns result if successful, null otherwise.
     */"""

if old_mount not in kt:
    raise SystemExit("SparseImageInstaller.kt: mount/extract anchor missing")
kt = kt.replace(old_mount, new_mount, 1)
installer.write_text(kt, encoding="utf-8", newline="\n")
print("[+] SparseImageInstaller.kt")

container = V / "Android" / "app" / "src" / "main" / "java" / "com" / "droidspaces" / "app" / "util" / "ContainerInstaller.kt"
ci = container.read_text(encoding="utf-8")
anchor_ci = """            logger.i("Container configuration saved")
            createdPaths.add(configFilePath)

            // Step 5.1: Write .env file if content exists"""
insert_ci = """            logger.i("Container configuration saved")
            createdPaths.add(configFilePath)

            if (config.useSparseImage) {
                SparseImageInstaller.unmountSparseImage(
                    mountPoint = "$containerPath/rootfs",
                    imgPath = rootfsPath,
                    logger = logger
                )
            }

            // Step 5.1: Write .env file if content exists"""
if anchor_ci not in ci:
    raise SystemExit("ContainerInstaller.kt: config anchor missing")
ci = ci.replace(anchor_ci, insert_ci, 1)
container.write_text(ci, encoding="utf-8", newline="\n")
print("[+] ContainerInstaller.kt")