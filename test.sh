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
rm -rf test_log
rm -rf in_files out_files my_cmd my_cmd2
rm -f ../pipex

echo "Creating files and directories used for the tests"
mkdir -p in_files out_files out_noperm test_log my_cmd my_cmd2
echo -ne "This is a basic test file\nblah blah blah\nblah blah\nblah" > in_files/in_ok
cp in_files/in_ok in_files/in_noperm
cp in_files/in_ok in_files/in_noread
chmod 000 in_files/in_noperm
chmod -r in_files/in_noread
chmod 000 out_noperm
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
echo -e "#include <stdio.h> \n int main(void) { printf(\"Hey\"); return (0); }" > my_cmd/main.c
cc my_cmd/main.c -o my_cmd/yo
cc my_cmd/main.c -o my_cmd/yo_noperm
chmod -x my_cmd/yo_noperm
rm -f my_cmd/main.c
echo -e "Hello" > my_cmd/no_exe
chmod +x my_cmd/no_exe

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
compile_name=$(ls -l .. | egrep -c " pipex$")
[[ compile_name -ne 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}name: KO\t${END}"
echo -ne "Relink:\t\t"
make -C .. > test_log/make_log 2> /dev/null
compile=$(< test_log/make_log grep -c "Nothing to be done")
[[ compile -ne 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO\t${END}" 

echo -ne "\nNorminette:\t"
norminette .. > test_log/norm_log
norm=$(<test_log/norm_log grep -c "Error")
[[ $norm -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $norm -ne 0 ]] && cat test_log/norm_log | egrep -v "OK!"

[[ ${compile_name} -eq 1 ]] || exit

echo -ne "\t\t\t\t\t\t\t\t\t\t\t\tRESULT\tEXIT\tERROR\tLEAK\tFD"
echo -e "\n\nBasic tests"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok ls ls out_files/out_ok\t\t\t\t\t"
$valgrind ../pipex in_files/in_ok "ls" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/ls" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "/usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok ls | ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok cat cat out_files/out_ok\t\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "/usr/bin/cat" | tail -1 | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main + $leak_first + $leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat | cat > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls -l\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "ls -l" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/ls -l" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat | ls -l > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"ls -l\" \"grep test\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "ls -l" "grep test" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/ls -l" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/grep" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok ls -l | grep test > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"head -3\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat -e" "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/head" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat -e | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


echo -e "\n\nEmpty args"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex \"\" \"cat -e\" \"head -3\" out_files/out_ok\t\t\t\t\t"
$valgrind ../pipex "" "cat -e" "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/head" | cut -d' ' -f 1)
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
2>/dev/null < "" cat -e | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"head -3\" \"\"\t\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat -e" "head -3" "" 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
< in_files/in_ok cat -e | 2>/dev/null head -3 > ""
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"\" \"head -3\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "" "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok "" | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat -e" "" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
< in_files/in_ok cat -e | 2>/dev/null "" > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \" \" \"head -3\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok " " "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/head" | cut -d' ' -f 1)
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
2>/dev/null < in_files/in_ok " " | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \" \" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat -e" " " out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
< in_files/in_ok cat -e | 2>/dev/null " " > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


echo -e "\n\nAbsolute paths"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/bin/cat -e\" \"ls\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "/bin/cat -e" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "/usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok /bin/cat -e | ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"/bin/ls\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat -e" "/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat -e | /bin/ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/bin/cat -e\" \"/bin/ls\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "/bin/cat -e" "/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok /bin/cat -e | /bin/ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nNon existing files/directories"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noexist \"cat\" \"cat\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_noexist "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
2>/dev/null < in_files/in_noexist cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex /bin/in_noexist \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex /bin/in_noexist "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
2>/dev/null < /bin/in_noexist cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_noexist/in_ok \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_noexist/in_ok "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
2>/dev/null < in_noexist/in_ok cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_noexist/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_noexist/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_noexist/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nNon existing commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cata\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cata" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
2>/dev/null < in_files/in_ok cata | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cata\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
2>/dev/null < in_files/in_ok cat | cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cata\" \"cata\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cata" "cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
2>/dev/null < in_files/in_ok cata | cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/bin/cata\" \"/bin/cata\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "/bin/cata" "/bin/cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
2>/dev/null < in_files/in_ok /bin/cata | /bin/cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -eq 2 ]] && [[ $err_nocmd -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nCustom commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe\" \"cat\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "my_cmd/exe" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok my_cmd/exe | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/exe\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "my_cmd/exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | my_cmd/exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe\" \"my_cmd2/exe\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "my_cmd/exe" "my_cmd2/exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok my_cmd/exe | my_cmd2/exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/yo\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "my_cmd/yo" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | my_cmd/yo > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nNon exe commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/no_exe\" \"cat\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "my_cmd/no_exe" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
#err=$(< test_log/valgrind_test${test_nb}_log grep -ci "not found")
err=1
2>/dev/null < in_files/in_ok my_cmd/no_exe | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/no_exe\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "my_cmd/no_exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
#err=$(< test_log/valgrind_test${test_nb}_log grep -ci "not found")
err=1
2>/dev/null < in_files/in_ok cat | my_cmd/no_exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nPermission errors"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noread \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_noread "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_noread cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noperm \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_noperm "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_noperm cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_files/out_nowrite\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_files/out_nowrite 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_files/out_nowrite_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_files/out_noperm\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_files/out_noperm 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_files/out_noperm_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_noperm/out_ok\t\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "cat" out_noperm/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_noperm/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe_noperm\" \"cat\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "my_cmd/exe_noperm" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok my_cmd/exe_noperm | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/exe_noperm\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat" "my_cmd/exe_noperm" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok cat | my_cmd/exe_noperm > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/yo_noperm\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat" "my_cmd/yo_noperm" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok cat | my_cmd/yo_noperm > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nInvalid command args"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"ls dir_noexist\" \"ls\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "ls dir_noexist" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
2>/dev/null < in_files/in_ok ls dir_noexist | ls > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls dir_noexist\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "ls dir_noexist" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
2>/dev/null < in_files/in_ok cat | ls dir_noexist > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_nofile -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"ls out_noperm\" \"ls\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "ls out_noperm" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok ls out_noperm | ls > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls out_noperm\" out_files/out_ok\t\t\t"
$valgrind ../pipex in_files/in_ok "cat" "ls out_noperm" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_second + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
2>/dev/null < in_files/in_ok cat | ls out_noperm > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


echo -e "\n\nSingle quote parsing"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"grep 'blah blah'\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat" "grep 'blah blah'" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | grep 'blah blah' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"grep 'blah'' blah'\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat" "grep 'blah'' blah'" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | grep 'blah'' blah' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"grep 'blah blah'''\" out_files/out_ok\t\t"
$valgrind ../pipex in_files/in_ok "cat" "grep 'blah blah'''" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | grep 'blah blah''' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls 'in_files' 'out_files'\" out_files/out_ok\t"
$valgrind ../pipex in_files/in_ok "cat" "ls 'in_files' 'out_files'" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_first=$(<test_log/valgrind_test${test_nb}_log grep -m1 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep  -m3 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep  -m4 -A 1 "HEAP SUMMARY" | tail -n1 | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak=$(echo "$leak_first + $leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -ci "no such file or directory")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -ci "permission denied")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -ci "command not found")
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | ls 'in_files' 'out_files' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test | wc -l)
[[ $diff -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t" && echo -e $diff > test_log/test_log
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && echo -e "User exit status=$codepipex - Test exit status=$codetest" > test_log/test_log
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

vg_error=$(echo -e $vg_ko_log | wc -l)
[[ $vg_error -gt 1 ]] && echo -ne "\nValgrind errors:\n${vg_ko_log}"
