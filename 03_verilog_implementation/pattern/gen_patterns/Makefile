IMG_FILE := image.csv
W_FILE := weight.csv

ifneq ($(wildcard $(IMG_FILE)),)
    $(info $(IMG_FILE) exists.)
else
    $(error $(IMG_FILE) doesn't exist.)
endif

ifneq ($(wildcard $(W_FILE)),)
    $(info $(W_FILE) exists.)
else
    $(error $(W_FILE) doesn't exist.)
endif

lenet_golden:
	g++ lenet_golden.cpp -o lenet_golden

gen: lenet_golden
	./lenet_golden
