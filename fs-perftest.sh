#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash -*-
# Summary: simplistic parameter scanning script.
#
# Copyright 2024 Michael Hucka.
# License: MIT license – see file "LICENSE" in the project website.
# Website: https://github.com/caltechlibrary/fs-perftest

device=sdb

# The value from /proc/meminfo is in kB. I can't figure out how to get
# numfmt to understand that, so this next thing is a hack.
totalram=$(grep -i memtotal /proc/meminfo | awk '{print $2}' | numfmt --from=iec --to=iec | tr -d 'M')

# For the test files created by the benchmarking utilities, we want something
# that's at least twice the size of the RAM on the system, so that the system
# can't cache it in memory.
doubleram=$((2*$totalram))

# Helper functions
# .............................................................................

pre_run() {
    # echo "Disabling disk drive caches."
    # megacli -LDSetProp DisDskCache -LAll -aAll

    if [ ! -e "test_file.0" ]; then
        echo "Prepping sysbench files ..."
        sysbench --test=fileio --file-total-size="$doubleram"G prepare  >/dev/null 2>&1
    else
        echo "Reusing existing sysbench files."
    fi
}

post_run() {
    # /bin/rm test.img
    # sysbench --test=fileio --file-total-size="$doubleram"G cleanup  >/dev/null 2>&1
    echo "Done."
    echo ""
    echo "******************************************************************"
    echo "If this is your last benchmarking run, clean up the test files!"
    echo "******************************************************************"
    echo ""
}

set_vm_dirty() {
    # This also echoes the setting, so it doubles as the print_ function.
    sysctl -w vm.dirty_bytes=$1
}

set_vm_background() {
    # This also echoes the setting, so it doubles as the print_ function.
    sysctl -w vm.dirty_background_bytes=$1
}

set_scheduler() {
    echo ""
    echo "======== scheduler: $1 ================================================"
    echo $1 > /sys/block/$device/queue/scheduler
}

print_scheduler() {
    echo -n "scheduler = "
    cat /sys/block/$device/queue/scheduler
}

set_nr_requests() {
    echo $1 > /sys/block/$device/queue/nr_requests
}

print_nr_requests() {
    echo -n "nr_requests = "
    cat /sys/block/$device/queue/nr_requests
}

set_fifo_batch() {
    if [ -e /sys/block/$device/queue/iosched/fifo_batch ]; then
        echo $1 > /sys/block/$device/queue/iosched/fifo_batch
    fi
}

print_fifo_batch() {
    if [ -e /sys/block/$device/queue/iosched/fifo_batch ]; then
        echo -n "fifo_batch = "
        cat /sys/block/$device/queue/iosched/fifo_batch
    else
        echo "no fifo_batch"
    fi
}

set_write_expire() {
    if [ -e /sys/block/$device/queue/iosched/write_expire ]; then
        echo $1 > /sys/block/$device/queue/iosched/write_expire
    fi
}

print_write_expire() {
    if [ -e /sys/block/$device/queue/iosched/write_expire ]; then
        echo -n "write_expire = "
        cat /sys/block/$device/queue/iosched/write_expire
    else
        echo "no write_expire"
    fi
}

set_read_ahead_kb() {
    echo $1 > /sys/block/$device/queue/read_ahead_kb
}

print_read_ahead_kb() {
    echo -n "read_ahead_kb = "
    cat /sys/block/$device/queue/read_ahead_kb
}

set_quantum() {
    echo $1 > /sys/block/$device/queue/iosched/quantum
}

print_quantum() {
    echo -n "quantum = "
    cat /sys/block/$device/queue/iosched/quantum
}

set_slice_idle() {
    echo $1 > /sys/block/$device/queue/iosched/slice_idle
}

print_slice_idle() {
    echo -n "slice_idle = "
    cat /sys/block/$device/queue/iosched/slice_idle
}

set_expire_centisecs() {
    # Tips from http://www.westnet.com/~gsmith/content/linux-pdflush.htm
    #
    # /proc/sys/vm/dirty_expire_centiseconds (default 3000): In hundredths of
    # a second, how long data can be in the page cache before it's considered
    # expired and must be written at the next opportunity. Note that this
    # default is very long: a full 30 seconds. That means that under normal
    # circumstances, unless you write enough to trigger the other pdflush
    # method, Linux won't actually commit anything you write until 30 seconds
    # later.
    #
    # Test lowering, but not to extremely low levels. Attempting to speed how
    # long pages sit dirty in memory can be accomplished here, but this will
    # considerably slow average I/O speed because of how much less efficient
    # this is. This is particularly true on systems with slow physical I/O to
    # disk. Because of the way the dirty page writing mechanism works, trying
    # to lower this value to be very quick (less than a few seconds) is
    # unlikely to work well. Constantly trying to write dirty pages out will
    # just trigger the I/O congestion code more frequently.

    echo $1 > /proc/sys/vm/dirty_expire_centisecs
}

print_expire_centisecs() {
    echo -n "dirty_expire_centisecs = "
    cat /proc/sys/vm/dirty_expire_centisecs
}

do_bonnie() {
    echo ""
    echo "~~~~~ Bonnie ~~~~~"
    drop_caches
    bonnie++ -s 128g -n 0 -f -c 6 -q
}

do_dd() {
    echo ""
    echo "~~~~~ dd ~~~~~"
    drop_caches
    for i in 1 2 3; do
        dd if=/dev/zero of=test.img conv=fdatasync bs=8k count=10240k
    done
}

do_sysbench() {
    ignorable='(Running the test|Extra file|128 files|total file size|Block size|Number of random|Read/Write ratio|Calling fsync|Using synchronous|Doing random|Threads started|Time limit exceeded|last message repeated|Done|Periodic FSYNC|sysbench 0.4.12|total time|Number of threads|total number of events|Initializing random number generator|Number of IO requests|Initializing worker threads|option is deprecated|sysbench 1.0.|General statistics:)'

    echo ""
    drop_caches
    sysbench --threads=16 --test=fileio --file-total-size="$doubleram"G --file-test-mode=rndrw --file-block-size=4096 --time=120 --max-requests=0 run |& egrep -v "$ignorable"
    sleep 30
}

drop_caches() {
    sync; echo 3 > /proc/sys/vm/drop_caches
}

do_tests() {
    for scheduler in none deadline; do
        for read_ahead_kb in 64 128 256 512 1024 2048;do
            for nr_requests in 64 128 256 512 916; do
                echo ""
                echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                # uptime

                set_scheduler $scheduler
                set_read_ahead_kb $read_ahead_kb
                set_nr_requests $nr_requests
                # set_quantum $quantum
                # set_slice_idle $slice_idle

                print_scheduler
                print_nr_requests
                print_read_ahead_kb
                # print_quantum
                # print_slice_idle
                # print_scheduler
                # print_fifo_batch
                # print_write_expire
                # print_vm_dirty_mb
                # print_vm_background_mb
                do_sysbench
                do_dd
                # do_bonnie
                echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            done
        done
    done
}


# Do the benchmarking
# .............................................................................

pre_run

do_tests

post_run
