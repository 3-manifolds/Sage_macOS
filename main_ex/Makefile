all: SageMath.c
	gcc -o SageMath -framework CoreFoundation SageMath.c
	codesign -v -s A3LBEGBB69 --timestamp --options runtime --force SageMath
