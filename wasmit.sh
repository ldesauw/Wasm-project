#!bin/bash

echo "resolving dependencies"

pathToScript=`pwd`

path1="/cheerp-wasm-out/"
path2="/llvm-clang-wasm-out/"
path3="/emcc-wasm-out/"
path4="/wasi-sdk-wasm-out/"

libclang_rt="libclang*/precompiled"

#pathx="llvm-clang-wasm-out/"
cheerp="/opt/cheerp/bin/clang"
#wasi="/home/theos/wasi-sdk-14.0/"

#sudo apt install wabt
#wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -
# Fingerprint: 6084 F3CF 814B 57C1 CF12 EFD5 15CF 4D18 AF4F 7421
#echo "deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-14 main" | sudo tee -a /etc/apt/sources.list
#echo "deb-src http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-14 main" | sudo tee -a /etc/apt/sources.list

## libclang 
cd /usr/lib/llvm-11/lib/clang/11.*/lib/ && sudo rm wasi 
cd /usr/lib/llvm-11/lib/clang/11.*/lib/ && sudo mkdir wasi
cd && git clone https://github.com/jedisct1/libclang_rt.builtins-wasm32.a.git
cd libclang*/precompiled && sudo cp libclang_rt.builtins-wasm32.a /usr/lib/llvm-11/lib/clang/11.*/lib/wasi/ 
cd


##llvm dependencies
sudo apt install llvm-11 wabt lld-11 clang-11 gcc clang
export PATH="/usr/local/opt/llvm/bin:$PATH"
cd && git clone https://github.com/CraneStation/wasi-libc.git 
cd wasi-libc && make install INSTALL_DIR=/tmp/wasi-libc && export PATH="/usr/local/opt/llvm/bin:$PATH"
#sudo apt install lld
echo "llvm dependencies are installed"


## emscripten dependencies
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install latest && ./emsdk activate latest && source ./emsdk_env.sh
cd
C_INCLUDE_PATH="/home/theos/emsdk/upstream/emscripten/system/include/"   
export C_INCLUDE_PATH 
CPLUS_INCLUDE_PATH="/home/theos/emsdk/upstream/emscripten/system/include/"  
export CPLUS_INCLUDE_PATH 
echo "emscripten dependencies are installed"


## cheerp dependencies
#sudo add-apt-repository  http://ppa.launchpad.net/leaningtech-dev/cheerp-ppa/ubuntu xenial main
echo "deb http://ppa.launchpad.net/leaningtech-dev/cheerp-ppa/ubuntu xenial main " | sudo tee -a /etc/apt/sources.list

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 84540D4B9BF457D5
sudo apt update
sudo apt install cheerp-core
echo "cheerp dependencies are installed"


## wasi-sdk dependencies
export WASI_VERSION=14 
export WASI_VERSION_FULL=${WASI_VERSION}.0 
wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_VERSION}/wasi-sdk-${WASI_VERSION_FULL}-linux.tar.gz 
tar xvf wasi-sdk-${WASI_VERSION_FULL}-linux.tar.gz
export WASI_SDK_PATH=`pwd`/wasi-sdk-${WASI_VERSION_FULL} 
CC="${WASI_SDK_PATH}/bin/clang --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot" 
echo "wasi-sdk dependencies are installed"

sudo apt update && sudo apt upgrade 

mkdir $pathToScript$path1 && mkdir $pathToScript$path2 && mkdir $pathToScript$path3 && mkdir $pathToScript$path4

## cargo-rust
cd && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup install 1.43.0
rustup override set 1.43.0

git clone https://github.com/sola-st/wasm-binary-security
cd wasm-binary-security/tool/wasm-security-analysis
cargo clean
cargo build && echo "cargo build success"




for i in $@ ;do

cd $pathToScript

pathnameext=$i

revname=$(echo $pathnameext | rev)
revy="${revname%%/*}"

nameext=$(echo $revy | rev)
name="${nameext%%.*}"


cp $nameext $pathToScript$path1 
cp $nameext $pathToScript$path2 
cp $nameext $pathToScript$path3 
cp $nameext $pathToScript$path4


##cheerp##
echo "cheerp setup for input file $i ..."
$cheerp -target cheerp $pathToScript$path1$nameext -O3 -o $pathToScript$path1$name"cheerp.js" && echo "js loader file created <cheerp>"
$cheerp -target cheerp -cheerp-mode=wasm -cheerp-wasm-loader=$pathToScript$path1$name"cheerp.js" -o0 -o $pathToScript$path1$name"cheerp.wasm" $pathToScript$path1$nameext -cheerp-pretty-code -cheerp-no-lto && echo "wasm binary created <cheerp>"
wasm2wat $pathToScript$path1$name"cheerp.wasm" -o $pathToScript$path1$name"cheerp.wat" && echo "wat file created <cheerp>"


##llvlm-clang##
echo "llvm-clang setup for input file $i ..."
#cd $pathToScript$path2 && clang --target=wasm32-uknown-wasi --sysroot /tmp/wasi-libc -emit-llvm -c -S  $nameext
#cd $pathToScript$path2 && llc -march=wasm32 -filetype=obj $name".ll" 
#wasm-objdump -x $path2$name.o
#wasm-ld -m wasm32 -L/tmp/wasi-libc/lib/wasm32-wasi --import-memory --no-entry --export-all $pathToScript$path2$name".o" -lc  -o $pathToScript$path2$name"llvm.wasm"
cd $pathToScript$path2 && clang-11 --target=wasm32-unkown-wasi --sysroot /tmp/wasi-libc -Os -s -o $name"llvm.wasm" $nameext && echo "wasm binary created <llvm>"
wasm2wat --enable-all $pathToScript$path2$name"llvm.wasm" -o $pathToScript$path2$name"llvm.wat" && echo"wat file created <llvm>"


##emsdk##
echo "emsdk setup for input file $i ..."
emcc $pathToScript$path3$nameext -o $pathToScript$path3$name"emcc.wasm" && echo "wasm binary created <emsdk>"
wasm2wat $pathToScript$path3$name"emcc.wasm" -o $pathToScript$path3$name"emcc.wat" && echo "wat file created <emsdk>"


##wasi-sdk##
echo "wasi-sdk setup for input file $i ..."
#$wasi"bin/clang" --sysroot=$wasi"share/wasi-sysroot" $path4$nameext -o $path4$name"wasi.wasm"
$CC $pathToScript$path4$nameext -o $pathToScript$path4$name"wasi.wasm" && echo "wasm binary created <wasi-sdk>"
wasm2wat $pathToScript$path4$name"wasi.wasm" -o $pathToScript$path4$name"wasi.wat" && echo "wat file created <wasi-sdk>"

done

cd 
home=`pwd`

for i in $(find $pathToScript"/" -name "*.wasm");do

pathnameext=$i
revname=$(echo $pathnameext | rev)
revy="${revname%%/*}"
nameext=$(echo $revy | rev)
name="${nameext%%.*}"

cp $i $home/wasm-binary-security/tool/wasm-security-analysis

cd $home/wasm-binary-security/tool/wasm-security-analysis && cargo clean 
cd $home/wasm-binary-security/tool/wasm-security-analysis && cargo run $nameext >> $name"-analysis.txt"

#path=$(echo $i | cut -c 2-)
#path=${pathnameext#"$namext"}
path=$( echo "$i" | sed -e "s/$nameext$//")

cp $home/wasm-binary-security/tool/wasm-security-analysis"/"$name"-analysis.txt" $path
rm $home/wasm-binary-security/tool/wasm-security-analysis"/"$name"-analysis.txt" 
rm $home/wasm-binary-security/tool/wasm-security-analysis"/"$nameext

done

rm -rf ~/.local/share/Trash/*

exit 1 