ITA="\033[3m"
UNDERL="\033[4m"
GREEN="\033[32m"
RED="\033[31m"
YEL="\033[33m"
END="\033[m"
BLU_BG="\033[44m"
YEL_BG="\033[43;1m"
RED_BG="\033[41;1m"

echo "Configure testing environment... "

echo "Creating files and directories used for the tests"
mkdir in_files out_files test_log my_cmd
touch in_files/in_blah out_files/out_blah
touch in_files/in_noperm out_files/out_noperm
chmod 000 in_files/in_noperm
chmod 000 out_files/out_noperm
cp /bin/cat my_cmd/exe

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


echo "Deleting all test files"
rm -rf in_files out_files test_log my_cmd
make fclean -C .. > /dev/null
