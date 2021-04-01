WORK_DIR=build_dir
VHDL_DIR=../

mkdir $WORK_DIR
cd $WORK_DIR

#clean working folder
ghdl --clean
rm work-obj93.cf

ghdl -a $VHDL_DIR/leds.vhdl $VHDL_DIR/spin1.vhdl