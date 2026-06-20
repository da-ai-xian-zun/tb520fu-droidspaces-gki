#!/system/bin/sh
echo "test1: fi if without semicolon"
if sh -c 'if [ 1 = 1 ]; then x=1; fi if [ 1 = 1 ]; then echo OK1; fi' 2>/tmp/t1.err; then
  echo "OK1 exit=0"
else
  echo "OK1 FAIL exit=$?"
  cat /tmp/t1.err
fi

echo "test2: fi; if with semicolon"
if sh -c 'if [ 1 = 1 ]; then x=1; fi; if [ 1 = 1 ]; then echo OK2; fi' 2>/tmp/t2.err; then
  echo "OK2 exit=0"
else
  echo "OK2 FAIL exit=$?"
  cat /tmp/t2.err
fi