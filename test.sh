ITA="\033[3m"
UNDERL="\033[4m"
GREEN="\033[32m"
RED="\033[31m"
YEL="\033[33m"
END="\033[m"
BLU_BG="\033[44m"
YEL_BG="\033[43;1m"
RED_BG="\033[41;1m"

valgrind="valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --trace-children=yes --track-fds=yes"
vg_ko_log=""
test_nb=0

echo "Configure testing environment... "

echo "Creating files and directories used for the tests"
rm -rf test_log
rm -rf in_files out_files my_cmd my_cmd2
mkdir in_files out_files test_log my_cmd my_cmd2
echo -ne "This is a basic test file\nblah blah blah\nblah blah\nblah" > in_files/in_ok
cp in_files/in_ok in_files/in_noperm
cp in_files/in_ok in_files/in_noread
chmod 000 in_files/in_noperm
chmod -r in_files/in_noread
touch out_files/out_noperm
touch out_files/out_nowrite
touch out_files/out_noperm_test
touch out_files/out_nowrite_test
chmod 000 out_files/out_noperm
chmod -w out_files/out_nowrite
chmod 000 out_files/out_noperm_test
chmod -w out_files/out_nowrite_test
cp /bin/cat my_cmd/exe
cp /bin/cat my_cmd/exe_noperm
chmod -x my_cmd/exe_noperm
cp /bin/ls my_cmd2/exe

echo "Testing pipex Makefile"
echo -ne "Rules:\t\t"
MAKE_RULE=$(<../Makefile grep -c "^\$(NAME)")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}NAME: KO\t${END}" 
MAKE_RULE=$(<../Makefile grep -c "^all")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}all: KO\t${END}" 
MAKE_RULE=$(<../Makefile grep -c "^clean")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}clean: KO\t${END}" 
MAKE_RULE=$(<../Makefile grep -c "^fclean")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}fclean: KO\t${END}" 
MAKE_RULE=$(<../Makefile grep -c "^re")
[[ $MAKE_RULE -gt 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}re: KO\t${END}" 

make fclean -C .. > /dev/null
echo -ne "Compile:\t"
make -C .. > /dev/null 2> test_log/make_log
compile=$(< test_log/make_log grep -ci "Error")
[[ compile -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}compile: KO\t${END}"
compile=$(ls -l .. | grep -c pipex)
[[ compile -ne 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}name: KO\t${END}"
echo -ne "Relink:\t\t"
make -C .. > test_log/make_log 2> /dev/null
compile=$(< test_log/make_log grep -c "Nothing to be done")
[[ compile -ne 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO\t${END}" 

echo -ne "\nNorminette:\t"
norminette .. > test_log/norm_log
norm=$(<test_log/norm_log grep -c "Error")
[[ $norm -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $norm -ne 0 ]] && cat test_log/norm_log | grep -v "OK!"

echo -e "#include <stdio.h> \n int main(void) { printf(\"Hey\"); return (0); }" > my_cmd/main.c
cc my_cmd/main.c -o my_cmd/yo
cc my_cmd/main.c -o my_cmd/yo_noperm
chmod -x my_cmd/yo_noperm

echo -ne "\t\t\t\t\t\t\t\t\t\t\tRESULT\tEXIT\tLEAK\tFD"
echo -e "\n\nBasic tests"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok ls ls out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "ls" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok ls | ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok cat cat out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok cat | cat > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls -l\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "ls -l" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok cat | ls -l > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"ls -l\" \"grep test\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "ls -l" "grep test" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok ls -l | grep test > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"head -3\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat -e" "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok cat -e | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

echo -e "\n\nAbsolute paths"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/bin/cat -e\" \"ls\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "/bin/cat -e" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok /bin/cat -e | ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"/bin/ls\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat -e" "/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok cat -e | /bin/ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/bin/cat -e\" \"/bin/ls\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "/bin/cat -e" "/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
< in_files/in_ok /bin/cat -e | /bin/ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

echo -e "\n\nNon existing files"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noexist \"cat\" \"cat\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_noexist "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_noexist cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex /bin/in_noexist \"cat\" \"cat\" out_files/out_ok\t\t\t"
$valgrind ../pipex /bin/in_noexist "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < /bin/in_noexist cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

echo -e "\n\nNon existing commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cata\" \"cat\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cata" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok cata | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cata\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok cat | cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cata\" \"cata\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cata" "cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok cata | cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/bin/cata\" \"/bin/cata\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "/bin/cata" "/bin/cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok /bin/cata | /bin/cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

echo -e "\n\nCustom commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe\" \"cat\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "my_cmd/exe" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok my_cmd/exe | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/exe\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat" "my_cmd/exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok cat | my_cmd/exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe\" \"my_cmd2/exe\" out_files/out_ok\t"
$valgrind ../pipex in_files/in_ok "my_cmd/exe" "my_cmd2/exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok my_cmd/exe | my_cmd2/exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

echo -e "\n\nPermission errors"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noread \"cat\" \"cat\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_noread "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_noread cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noperm \"cat\" \"cat\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_noperm "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_noperm cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_files/out_nowrite\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_files/out_nowrite 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_files/out_nowrite_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_files/out_noperm\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_files/out_noperm 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_files/out_noperm_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe_noperm\" \"cat\" out_files/out_ok\t"
$valgrind ../pipex in_files/in_ok "my_cmd/exe_noperm" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok my_cmd/exe_noperm | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/exe_noperm\" out_files/out_ok\t"
$valgrind ../pipex in_files/in_ok "cat" "my_cmd/exe_noperm" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c "Open file descriptor")
2>/dev/null < in_files/in_ok cat | my_cmd/exe_noperm > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more valgrind error info\n"



vg_error=$(echo -e $vg_ko_log | wc -l)
[[ $vg_error -ne 0 ]] && echo -ne "\nValgrind errors:\n${vg_ko_log}"
