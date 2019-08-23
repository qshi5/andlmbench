#!/bin/bash

# LMBENCH configuration
MAXMEMSIZE="1024M"
BLOCKSIZE=512

LMBENCHDIR="/usr/local/bin"
UBUNTU=$(cat /etc/lsb-release | grep "Ubuntu" | grep -c "")
if [ "$UBUNTU" != "0" ]; then
	LMBENCHDIR="/usr/lib/lmbench/bin/x86_64-linux-gnu"
	export PATH=$PATH:/usr/lib/lmbench/bin/x86_64-linux-gnu
fi
TMPDIR=`pwd ~`
TMP="$TMPDIR/file.tmp"
func="_func"

if [ "$1" == "-d" ]; then
	HELPMSG=1
fi

TOOLS=(dd sed grep lat_syscall mhz lat_sig lat_proc)
BWTOOLS=(bw_file_rd bw_mem bw_mmap_rd)
LATTOOLS=(lat_mem_rd lat_mmap lat_ops lat_fs lat_ctx)

# Input: "MB MB_PER_SEC"
# Output: "XX megabytes XX megabytes per second"
convert_mb_mbpersec() {
	array=(`echo "$1"`)
	echo "${array[0]}MB ${array[1]}MB/s"
}

# Print command and run the command
runcmd() {
	if [ "$HELPMSG" == "1" ]; then
		echo "$1"
	fi
	$1 2>&1
}

verifytools() {
	for tool in $1
	do
		valid=$(which $tool | grep "" -c)
		if [ "$valid" != "1" ]; then
			echo "ERROR: $tool doesn't exist to run lmbench tool!!!"
			exit 1
		fi
	done
}

sanitytools() {
	verifytools "${TOOLS[*]}"
	verifytools "${BWTOOLS[*]}"
	verifytools "${LATTOOLS[*]}"
}

# Input: (XXM min_size) Must be M, not k or m
# Output: array of Input, divide by 2 until it gets 512
split_mem_test_size() {
	size=(`echo "$1" | sed 's/M//g'`)
	size=`expr $size \* 1024 \* 1024`
	index=0
	while (( $size >= $2 ))
	do
		sizearray[$index]=$size
		size=`expr $size \/ 2`
		index=`expr $index + 1`
	done
	count=0
	while (( $index > 0 ))
	do
		index=`expr $index - 1`
		alignedarray[$count]=${sizearray[$index]}
		count=`expr $count + 1`
	done
	echo ${alignedarray[@]}
}

# Input: (XXM block_size) Must be M, not k or m
# Output: array of Input, divide by 2 until it gets 512
convert_mb_to_block() {
	size=(`echo "$1" | sed 's/M//g'`)
	size=`expr $size \* 1024 \* 1024`
	blocks=`expr $size \/ $2`
	echo $blocks
}

#
# Get system information and verify configuration
#
get_system_info() {
	echo "[LMBENCH_VER 3.0-a9]"
	echo "[CPU: `cat /proc/cpuinfo | grep "model name" | head -1`]"
	echo "[Processors: `cat /proc/cpuinfo | grep processor | grep "" -c`]"
	echo "[OS: `uname -a`]"
	echo "[DISTRIB: `cat /etc/lsb-release | grep DISTRIB_DESCRIPTION`]"
	echo "[CHROME MILESTONE: `cat /etc/lsb-release | grep CHROMEOS_RELEASE_CHROME_MILESTONE`]"
	echo "[CHROME BOARD: `cat /etc/lsb-release | grep CHROMEOS_RELEASE_BOARD`]"
	echo "[CHROMEOS: `cat /etc/lsb-release | grep CHROMEOS_RELEASE_DESCRIPTION`]"
	echo "[KERNEL VER: `uname -a`]"
	echo "[mhz: `mhz`]"
	echo "[`cat /proc/meminfo | head -1`]"
	echo "[MB for test: $MAXMEMSIZE]"
	echo "[ENOUGH: `enough`]"
}


get_system_perf() {
	runcmd "lat_syscall null"
	runcmd "lat_syscall read $TMP"
	runcmd "lat_syscall write $TMP"
	runcmd "lat_syscall stat $TMP"
	runcmd "lat_syscall fstat $TMP"
	runcmd "lat_syscall open $TMP"
	runcmd "lat_sig install"
	runcmd "lat_sig catch"
	runcmd "lat_sig prot $TMP"
	runcmd "lat_pipe"
	runcmd "bw_pipe"
	runcmd "lat_unix"
	runcmd "bw_unix"
	runcmd "lat_proc fork"
	runcmd "lat_proc exec"
	runcmd "lat_proc procedure"
	runcmd "lat_pagefault $TMP"
}

#
# lat_mmap
#
lat_mmap_func() {
echo ""
echo "lat_mmap"
echo "=========="
if [ "$HELPMSG" == "1" ]; then
echo "How fast a mapping can be made and unmade. This is useful because it is a fundemental"
echo "part of processes that use SunOS style shared libraries (the libraries are mapped in"
echo "at process start up time and unmapped at process exit)."
echo "The benchmark maps in and unmaps the first \fIsize bytes of the file repeatedly and"
echo "reports the average time for one mapping/unmapping."
echo ""
echo "The size specification may end with ``k'' or ``m'' to mean kilobytes"
echo "(* 1024) or megabytes (* 1024 * 1024)."
echo ""
fi

echo "MB usecs"
table=$(split_mem_test_size $MAXMEMSIZE 1048576)
for size in ${table[@]}
do
	runcmd "$LMBENCHDIR/lat_mmap $size $TMP"
done
}

#
# lat_ops
#
lat_ops_func() {
echo ""
echo "lat_ops"
echo "=========="
if [ "$HELPMSG" == "1" ]; then
echo "measures the latency of basic CPU operations, such as integer ADD."
echo "integer bit, add, mul, div, mod operations maximum parallelism for integer XOR,"
echo "ADD, MUL, DIV, MOD operations."
echo "uint64 bit, add, mul, div, mod operations maximum parallelism for"
echo "uint64 XOR, ADD, MUL, DIV, MOD operations."
echo ""
echo "float add, mul, div operations. maximum parallelism for flot ADD, MUL, DIV operations."
echo ""
echo "double add, mul, div operations. maximum parallelism for flot ADD, MUL, DIV operations."
echo ""
fi

runcmd "$LMBENCHDIR/lat_ops"
}

#
# lat_usleep
#
#lat_usleep_func() {
#echo ""
#echo "lat_usleep"
#echo "=========="
#runcmd "$LMBENCHDIR/lat_usleep -u usleep 10"
#runcmd "$LMBENCHDIR/lat_usleep -u usleep 100"
#runcmd "$LMBENCHDIR/lat_usleep -u usleep 1000"
#runcmd "$LMBENCHDIR/lat_usleep -u nanosleep 10"
#runcmd "$LMBENCHDIR/lat_usleep -u nanosleep 100"
#runcmd "$LMBENCHDIR/lat_usleep -u nanosleep 1000"
#runcmd "$LMBENCHDIR/lat_usleep -u select 10"
#runcmd "$LMBENCHDIR/lat_usleep -u select 100"
#runcmd "$LMBENCHDIR/lat_usleep -u select 1000"
#runcmd "$LMBENCHDIR/lat_usleep -u itimer 10"
#runcmd "$LMBENCHDIR/lat_usleep -u itimer 100"
#runcmd "$LMBENCHDIR/lat_usleep -u itimer 1000"
#}

#
# lat_fs
#
lat_fs_func() {
echo ""
echo "lat_fs"
echo "=========="
if [ "$HELPMSG" == "1" ]; then
echo "creates a number of small files in the current working directory and then"
echo "removes the files. Both the creation and removal of the files is timed."
echo ""
fi

echo "size of file, number created, creations per second, removals per second"
runcmd "$LMBENCHDIR/lat_fs -s 4K $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 16K $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 32K $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 64K $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 128K $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 512K $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 640K $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 1M $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 4M $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 8M $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 16M $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 32M $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 64M $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 128M $TMPDIR"
runcmd "$LMBENCHDIR/lat_fs -s 256M $TMPDIR"
}

#
# lat_cmd
#
lat_cmd_func() {
echo ""
echo "lat_cmd"
echo "=========="
#runcmd "$LMBENCHDIR/lat_cmd ls"
#runcmd "$LMBENCHDIR/lat_cmd ps"
}

#
# lat_mem_rd
#
lat_mem_rd_func() {
echo ""
echo "lat_mem_rd"
echo "=========="
runcmd "$LMBENCHDIR/lat_mem_rd 1024M 8M"
}

#
# lat_ctx
#
lat_ctx_func() {
echo ""
echo "lat_ctx"
echo "=========="
if [ "$HELPMSG" == "1" ]; then
echo "measures context switching time for any reasonable number of processes of any reasonable size."
echo "The processes are connected in a ring of Unix pipes. Each process reads a token from its pipe,"
echo "possibly does some work, and then writes the token to the next process."
echo "Processes may vary in number. Smaller numbers of processes result in faster context switches."
echo "More than 20 processes is not supported."
echo "Processes may vary in size. A size of zero is the baseline process that does nothing except"
echo "pass the token on to the next process. A process size of greater than zero means that the process"
echo "does some work before passing on the token. The work is simulated as the summing up of"
echo "an array of the specified size. The summing is an unrolled loop of about a 2.7 thousand instructions."
echo "The effect is that both the data and the instruction cache get polluted by some amount before"
echo "the token is passed on. The data cache gets polluted by approximately the process ``size''."
echo "The instruction cache gets polluted by a constant amount, approximately 2.7 thousand instructions."
echo "The pollution of the caches results in larger context switching times for the larger processes."
echo "This may be confusing because the benchmark takes pains to measure only the context switch time,"
echo "not including the overhead of doing the work. The subtle point is that the overhead is measured"
echo "using hot caches. As the number and size of the processes increases, the caches are"
echo "more and more polluted until the set of processes do not fit. The context switch times"
echo "go up because a context switch is defined as the switch time plus the time it takes to"
echo "restore all of the process state, including cache state. This means that the switch includes"
echo "the time for the cache misses on larger processes."
echo ""
fi

echo "size, ovr: non-context switching overhead(usec)"
echo "number of processes, cost of context switch(usec)"
runcmd "$LMBENCHDIR/lat_ctx -s 0 processes 2"
runcmd "$LMBENCHDIR/lat_ctx -s 0 processes 4"
runcmd "$LMBENCHDIR/lat_ctx -s 0 processes 8"
runcmd "$LMBENCHDIR/lat_ctx -s 0 processes 16"
runcmd "$LMBENCHDIR/lat_ctx -s 0 processes 20"
runcmd "$LMBENCHDIR/lat_ctx -s 128K processes 2"
runcmd "$LMBENCHDIR/lat_ctx -s 128K processes 4"
runcmd "$LMBENCHDIR/lat_ctx -s 128K processes 8"
runcmd "$LMBENCHDIR/lat_ctx -s 128K processes 16"
runcmd "$LMBENCHDIR/lat_ctx -s 128K processes 20"
}


#
# bw_file_rd
#
bw_file_rd_func() {
echo ""
echo "bw_file_rd"
echo "=========="
if [ "$HELPMSG" == "1" ]; then
echo "bw_file_rd times the read of the specified file in 64KB blocks."
echo "Results are reported in megabytes read per second. The data is"
echo "not accessed in the user program; the benchmark relies on the"
echo "operating systems read interface to have actually moved the data."
echo ""
echo "The size specification may end with ``k'' or ``m'' to mean kilobytes"
echo "(* 1024) or megabytes (* 1024 * 1024)."
echo ""
fi

echo "MB MB/s"
table=$(split_mem_test_size $MAXMEMSIZE 512)
for size in ${table[@]}
do
	runcmd "$LMBENCHDIR/bw_file_rd $size open2close $TMP"
done
}

#
# bw_mem
#
bw_mem_func() {
echo ""
echo "bw_mem"
echo "======"
echo "MB MB/s"

echo ""
echo "memory read bandwidth"
echo "---------------------"
echo "MB MB/s"
table=$(split_mem_test_size $MAXMEMSIZE 512)
for size in ${table[@]}
do
	runcmd "$LMBENCHDIR/bw_mem $size rd"
done

echo ""
echo "memory write bandwidth"
echo "---------------------"
echo "MB MB/s"
table=$(split_mem_test_size $MAXMEMSIZE 512)
for size in ${table[@]}
do
	runcmd "$LMBENCHDIR/bw_mem $size wr"
done

}

#
# bw_mmap_rd
#
bw_mmap_rd_func() {
echo ""
echo "bw_mmap_rd"
echo "=========="
echo "MB MB/s"

echo ""
echo "mmap read bandwidth"
echo "---------------------"
echo "MB MB/s"
table=$(split_mem_test_size $MAXMEMSIZE 512)
for size in ${table[@]}
do
	runcmd "$LMBENCHDIR/bw_mmap_rd $size mmap_only $TMP"
done

echo ""
echo "mmap read open2close bandwidth"
echo "---------------------"
echo "MB MB/s"
table=$(split_mem_test_size $MAXMEMSIZE 512)
for size in ${table[@]}
do
	runcmd "$LMBENCHDIR/bw_mmap_rd $size open2close $TMP"
done

}

other_measure_func() {
echo ""
echo "par_ops"
echo "---------------------"
runcmd "par_ops"

echo ""
echo "par_mem"
echo "---------------------"
runcmd "par_mem -M 32M"

echo ""
echo "stream"
echo "---------------------"
if [ "$UBUNTU" != "0" ]; then
	runcmd "stream -M 128K"
else
	runcmd "stream.lmbench -M 128K"
fi

echo ""
echo "tlb"
echo "---------------------"
runcmd "tlb -M 1M"

#echo ""
#echo "cache"
#echo "---------------------"
#runcmd "cache"
}

#####################################################################
# MAIN
#####################################################################
# Verify tools first
sanitytools

echo "###############################"
echo " LMBENCH MEASUREMENT"
echo "###############################"

blocks=$(convert_mb_to_block $MAXMEMSIZE $BLOCKSIZE)
dd if=/dev/zero of=$TMP bs=$BLOCKSIZE count=$blocks 1>&2

# Get info
get_system_info
get_system_perf

echo "------------------------------"
echo "1. BANDWIDTH MEASUREMENT"
echo "------------------------------"
for bw_measure in ${BWTOOLS[@]}
do
	$bw_measure$func
done
echo "------------------------------"
echo "2. LATENCY MEASUREMENTS"
echo "------------------------------"
for lat_measure in ${LATTOOLS[@]}
do
	$lat_measure$func
done

echo "------------------------------"
echo "3. OTHER MEASUREMENTS"
echo "------------------------------"
other_measure_func

rm $TMP
exit 0
