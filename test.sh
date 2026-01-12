ITA="\033[3m"
UNDERL="\033[4m"
GREEN="\033[32m"
RED="\033[31m"
YEL="\033[33m"
END="\033[m"
BLU_BG="\033[44m"
YEL_BG="\033[43;1m"
RED_BG="\033[41;1m"

pipex_dir=".."
valgrind="valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --trace-children=yes --track-fds=yes"
vg_ko_log=""
err_log=""
diff_log=""
out_err_log=""
test_nb=0

echo "Configure testing environment... "
rm -rf test_log
rm -rf in_files out_files my_cmd my_cmd2
rm -f $pipex_dir/pipex

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
MAKE_RULE=$(<$pipex_dir/Makefile grep -c "^\$(NAME)")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}NAME: KO\t${END}" 
MAKE_RULE=$(<$pipex_dir/Makefile grep -c "^all")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}all: KO\t${END}" 
MAKE_RULE=$(<$pipex_dir/Makefile grep -c "^clean")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}clean: KO\t${END}" 
MAKE_RULE=$(<$pipex_dir/Makefile grep -c "^fclean")
[[ $MAKE_RULE -gt 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}fclean: KO\t${END}" 
MAKE_RULE=$(<$pipex_dir/Makefile grep -c "^re")
[[ $MAKE_RULE -gt 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}re: KO\t${END}" 

make fclean -C .. > /dev/null
echo -ne "Compile:\t"
make -C .. > /dev/null 2> test_log/make_log
compile=$(< test_log/make_log grep -oi "Error" | wc -l)
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
$valgrind $pipex_dir/pipex in_files/in_ok "ls" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok ls | ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok cat cat out_files/out_ok\t\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/cat" | tail -1 | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main + $leak_first + $leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat | cat > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls -l\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "ls -l" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls -l" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat | ls -l > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"ls -l\" \"grep test\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "ls -l" "grep test" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls -l" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/grep" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok ls -l | grep test > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"head -3\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat -e" "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/head" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat -e | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


echo -e "\n\nEmpty args"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex \"\" \"cat -e\" \"head -3\" out_files/out_ok\t\t\t\t\t"
$valgrind $pipex_dir/pipex "" "cat -e" "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/head" | cut -d' ' -f 1)
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
2>/dev/null < "" cat -e | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"head -3\" \"\"\t\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat -e" "head -3" "" 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
< in_files/in_ok cat -e | 2>/dev/null head -3 > ""
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"\" \"head -3\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "" "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok "" | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat -e" "" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
< in_files/in_ok cat -e | 2>/dev/null "" > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \" \" \"head -3\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok " " "head -3" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/head" | cut -d' ' -f 1)
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
2>/dev/null < in_files/in_ok " " | head -3 > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \" \" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat -e" " " out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
< in_files/in_ok cat -e | 2>/dev/null " " > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


echo -e "\n\nAbsolute paths"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/usr/bin/cat -e\" \"ls\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "/usr/bin/cat -e" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok /usr/bin/cat -e | ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat -e\" \"/usr/bin/ls\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat -e" "/usr/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok cat -e | /usr/bin/ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/usr/bin/cat -e\" \"/usr/bin/ls\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "/usr/bin/cat -e" "/usr/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
< in_files/in_ok /usr/bin/cat -e | /usr/bin/ls > out_files/out_ok_test
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nNon existing files/directories"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noexist \"cat\" \"cat\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_noexist "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
2>/dev/null < in_files/in_noexist cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex /bin/in_noexist \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex /bin/in_noexist "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
2>/dev/null < /bin/in_noexist cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_noexist/in_ok \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_noexist/in_ok "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
2>/dev/null < in_noexist/in_ok cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_noexist/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "cat" out_noexist/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_noexist/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nNon existing commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cata\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cata" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
2>/dev/null < in_files/in_ok cata | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cata\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
2>/dev/null < in_files/in_ok cat | cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cata\" \"cata\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cata" "cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
2>/dev/null < in_files/in_ok cata | cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"/usr/bin/cata\" \"/usr/bin/cata\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "/usr/bin/cata" "/usr/bin/cata" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
2>/dev/null < in_files/in_ok /usr/bin/cata | /usr/bin/cata > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -eq 2 ]] && [[ $err_nocmd -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -ne 2 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo -e "\tmissing std_err: \"no such file or directory\"")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nCustom commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe\" \"cat\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "my_cmd/exe" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: my_cmd/exe" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok my_cmd/exe | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/exe\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "my_cmd/exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: my_cmd/exe" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | my_cmd/exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe\" \"my_cmd2/exe\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "my_cmd/exe" "my_cmd2/exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: my_cmd/exe" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: my_cmd2/exe" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok my_cmd/exe | my_cmd2/exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/yo\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "my_cmd/yo" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: my_cmd/yo" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | my_cmd/yo > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nNon exe commands"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/no_exe\" \"cat\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "my_cmd/no_exe" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
#err=$(< test_log/valgrind_test${test_nb}_log grep -oi "not found" | wc -l)
err=1
2>/dev/null < in_files/in_ok my_cmd/no_exe | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/no_exe\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "my_cmd/no_exe" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
#err=$(< test_log/valgrind_test${test_nb}_log grep -oi "not found" | wc -l)
err=1
2>/dev/null < in_files/in_ok cat | my_cmd/no_exe > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nPermission errors"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noread \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_noread "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_noread cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_noperm \"cat\" \"cat\" out_files/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_noperm "cat" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_noperm cat | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_files/out_nowrite\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "cat" out_files/out_nowrite 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_files/out_nowrite_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_files/out_noperm\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "cat" out_files/out_noperm 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_files/out_noperm_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"cat\" out_noperm/out_ok\t\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "cat" out_noperm/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok cat | 2>/dev/null cat > out_noperm/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"my_cmd/exe_noperm\" \"cat\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "my_cmd/exe_noperm" "cat" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_second" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok my_cmd/exe_noperm | cat > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/exe_noperm\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "my_cmd/exe_noperm" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok cat | my_cmd/exe_noperm > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"my_cmd/yo_noperm\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "my_cmd/yo_noperm" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok cat | my_cmd/yo_noperm > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nInvalid command args"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"ls dir_noexist\" \"ls\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "ls dir_noexist" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/ls" | tail -1 | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
2>/dev/null < in_files/in_ok ls dir_noexist | ls > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls dir_noexist\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "ls dir_noexist" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls dir_noexist" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
2>/dev/null < in_files/in_ok cat | ls dir_noexist > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nofile -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nofile -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"no such file or directory\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"ls out_noperm\" \"ls\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "ls out_noperm" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m2 "Command: /usr/bin/ls" | tail -1 | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok ls out_noperm | ls > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls out_noperm\" out_files/out_ok\t\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "ls out_noperm" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls out_noperm" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
2>/dev/null < in_files/in_ok cat | ls out_noperm > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_noperm -eq 1 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_noperm -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"permission denied\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"


echo -e "\n\nEmpty environment"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\tenv -i ./pipex in_files/in_ok \"cat\" \"ls\" out_files/out_ok\t\t\t"
$valgrind env -i $pipex_dir/pipex in_files/in_ok "cat" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
path_tmp=$PATH
unset PATH
2>/dev/null < in_files/in_ok cat | ls > out_files/out_ok_test 2>/dev/null
codetest=$?
PATH=$path_tmp && export PATH
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -eq 2 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -ne 2 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\tenv -i ./pipex in_files/in_ok \"/usr/bin/cat\" \"ls\" out_files/out_ok\t\t"
$valgrind env -i $pipex_dir/pipex in_files/in_ok "/usr/bin/cat" "ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
path_tmp=$PATH
unset PATH
2>/dev/null < in_files/in_ok /usr/bin/cat | ls > out_files/out_ok_test 2>/dev/null
codetest=$?
PATH=$path_tmp && export PATH
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\tenv -i ./pipex in_files/in_ok \"cat\" \"/usr/bin/ls\" out_files/out_ok\t\t"
$valgrind env -i $pipex_dir/pipex in_files/in_ok "cat" "/usr/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log grep -v "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
path_tmp=$PATH
unset PATH
2>/dev/null < in_files/in_ok cat | /usr/bin/ls > out_files/out_ok_test 2>/dev/null
codetest=$?
PATH=$path_tmp && export PATH
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err_nocmd -ne 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err_nocmd -eq 0 ]] && out_err_log+=$(echo "Test${test_nb}: missing std_err: \"command not found\"\n")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\tenv -i ./pipex in_files/in_ok \"/usr/bin/cat\" \"/usr/bin/ls\" out_files/out_ok\t"
$valgrind env -i $pipex_dir/pipex in_files/in_ok "/usr/bin/cat" "/usr/bin/ls" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
path_tmp=$PATH
unset PATH
2>/dev/null < in_files/in_ok /usr/bin/cat | /usr/bin/ls > out_files/out_ok_test 2>/dev/null
codetest=$?
PATH=$path_tmp && export PATH
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n\nSingle quote parsing"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"grep 'blah blah'\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "grep 'blah blah'" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/grep" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | grep 'blah blah' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"grep 'blah'' blah'\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "grep 'blah'' blah'" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/grep" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | grep 'blah'' blah' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"grep 'blah blah'''\" out_files/out_ok\t\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "grep 'blah blah'''" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/grep" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | grep 'blah blah''' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

test_nb=$(echo "$test_nb + 1" | bc)
echo -ne "-> Test ${test_nb}:\t./pipex in_files/in_ok \"cat\" \"ls 'in_files' 'out_files'\" out_files/out_ok\t"
$valgrind $pipex_dir/pipex in_files/in_ok "cat" "ls 'in_files' 'out_files'" out_files/out_ok 2> test_log/valgrind_test${test_nb}_log
codepipex=$?
cmd_1_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/cat" | cut -d' ' -f 1)
cmd_2_id=$(<test_log/valgrind_test${test_nb}_log grep -m1 "Command: /usr/bin/ls" | cut -d' ' -f 1)
leak_first=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_1_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_second=$(<test_log/valgrind_test${test_nb}_log grep "$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g")
leak_main=$(<test_log/valgrind_test${test_nb}_log egrep -v "$cmd_1_id|$cmd_2_id" | grep -A 1 "HEAP SUMMARY" | egrep -o "[0-9]*,?[0-9]+ bytes" | cut -d' ' -f1 | sed "s/,//g" | sed "{:q;N;s/\n/\+/g;t q}")
leak=$(echo "$leak_main+$leak_first" | bc)
open=$(<test_log/valgrind_test${test_nb}_log grep -c " file descriptor")
err_nofile=$(< test_log/valgrind_test${test_nb}_log grep -oi "no such file or directory" | wc -l)
err_noperm=$(< test_log/valgrind_test${test_nb}_log grep -oi "permission denied" | wc -l)
err_nocmd=$(< test_log/valgrind_test${test_nb}_log grep -oi "command not found" | wc -l)
err=$(echo "$err_nofile + $err_noperm + $err_nocmd" | bc)
2>/dev/null < in_files/in_ok cat | ls 'in_files' 'out_files' > out_files/out_ok_test 2>/dev/null
codetest=$?
diff=$(diff out_files/out_ok out_files/out_ok_test)
[[ $(echo -ne $diff | wc -l) -ne 0 ]] && $diff_log+="\nTest{test_nb}:\n${diff}"
[[ $(echo -ne $diff | wc -l) -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -eq $codetest ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $codepipex -ne $codetest ]] && err_log+="Test${test_nb}: User exit status=$codepipex - Test exit status=$codetest\n"
[[ $err -eq 0 ]]  && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $err -ne 0 ]] && out_err_log+=$(echo -e "Test${test_nb}:") && out_err_log+=$(< test_log/valgrind_test${test_nb}_log egrep "(no such file or directory|permission denied|command not found)")
[[ $leak -eq 0 ]] && echo -ne "${GREEN}OK${END}\t" || echo -ne "${RED}KO${END}\t"
[[ $open -eq 0 ]] && echo -e "${GREEN}OK${END}\t" || echo -e "${RED}KO${END}\t"
[[ $leak -ne 0 ]] || [[ $open -ne 0 ]] && vg_ko_log+="Test${test_nb}: check test_log/valgrind_test${test_nb}_log for more info\n"

echo -e "\n${YEL}Out file errors:${END}\n$diff_log" && echo -ne $diff_log > test_log/diff_log
echo -e "${YEL}Exit code errors:${END}\n$err_log" && echo -ne $err_log > test_log/test_log
echo -e "${YEL}Error output errors:${END}\n$out_err_log" && echo -ne $out_err_log > test_log/test_out_log

vg_error=$(echo -e $vg_ko_log | wc -l)
[[ $vg_error -gt 1 ]] && echo -ne "${YEL}Valgrind errors:${END}\n${vg_ko_log}"
