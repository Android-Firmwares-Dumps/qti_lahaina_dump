#! /vendor/bin/sh

#ifdef OPLUS_FEATURE_ZRAM_WRITEBACK
#Huangwen.Chen@OPTIMIZATION, 2021/01/11, Add for zram writeback
function oppo_configure_zram_parameters() {
   MemTotalStr=`cat /proc/meminfo | grep MemTotal`
   MemTotal=${MemTotalStr:16:8}

   if [ $MemTotal -le 524288 ]; then
       #config 384MB zramsize with ramsize 512MB
       echo 402653184 > /sys/block/zram0/disksize
   elif [ $MemTotal -le 1048576 ]; then
       #config 768MB zramsize with ramsize 1GB
       echo 805306368 > /sys/block/zram0/disksize
   elif [ $MemTotal -le 2097152 ]; then
       #config 1GB+256MB zramsize with ramsize 2GB
       echo lz4 > /sys/block/zram0/comp_algorithm
       echo 1342177280 > /sys/block/zram0/disksize
    elif [ $MemTotal -le 3145728 ]; then
       #config 1GB+512MB zramsize with ramsize 3GB
       echo 1610612736 > /sys/block/zram0/disksize
    elif [ $MemTotal -le 4194304 ]; then
       #config 2GB+512MB zramsize with ramsize 4GB
       echo 2684354560 > /sys/block/zram0/disksize
    elif [ $MemTotal -le 6291456 ]; then
       #config 3GB zramsize with ramsize 6GB
       echo 3221225472 > /sys/block/zram0/disksize
    else
       #config 4GB zramsize with ramsize >=8GB
       echo 4294967296 > /sys/block/zram0/disksize
    fi
}

function configure_zram_writeback() {
    # get backing storage size, unit: MB
    backing_dev_size=$(getprop persist.vendor.zwriteback.backing_dev_size)
    case $backing_dev_size in
        [1-9])
            ;;
        [1-9][0-9]*)
            ;;
        *)
            backing_dev_size=2048
            ;;
    esac

    # create backing storage
    # check if dd command success
    ret=$(dd if=/dev/zero of=/data/vendor/swap/zram_wb bs=1m count=$backing_dev_size 2>&1)
    if [ $? -ne 0 ];then
        rm -f /data/vendor/swap/zram_wb
        echo "zwb $ret" > /dev/kmsg
        return 1
    fi

    # check if attaching file success
    losetup -f
    loop_device=$(losetup -f -s /data/vendor/swap/zram_wb 2>&1)
    if [ $? -ne 0 ];then
        rm -f /data/vendor/swap/zram_wb
        echo "zwb $loop_device" > /dev/kmsg
        return 1
    fi
    echo $loop_device > /sys/block/zram0/backing_dev

    mem_limit=$(getprop persist.vendor.zwriteback.mem_limit)
    case $mem_limit in
        [1-9])
            mem_limit="${mem_limit}M"
            ;;
        [1-9][0-9]*)
            mem_limit="${mem_limit}M"
            ;;
        *)
            mem_limit="1G"
            ;;
    esac
    echo $mem_limit > /sys/block/zram0/mem_limit
}

function configure_zwb_parameters() {
    while :
    do
        postboot_running=`getprop vendor.sys.zwriteback.postboot`
        if [ "$postboot_running" == "2" ]; then
            setprop vendor.sys.zwriteback.postboot 3
            exit 0
        elif [ "$postboot_running" == "3" ]; then
            break
        fi
        sleep 1
    done
    zwb_switch=`getprop persist.vendor.zwriteback.enable`
    case "$zwb_switch" in
        "0")
            # disable zram writeback
            oppo_zram_disksize=$(cat /sys/block/zram0/disksize)
            if [ $oppo_zram_disksize == "0" ];then
                retry=0
                return
            fi

            echo "zwb swapoff start" > /dev/kmsg
            ret=$(swapoff /dev/block/zram0 2>&1)
            if [ $? -ne 0 ];then
                echo "zwb $ret" > /dev/kmsg
                return
            fi
            echo "zwb swapoff done" > /dev/kmsg
            # detaching loop device and clear backing_dev file
            loop_device_file="/sys/block/zram0/backing_dev"
            if [ -f $loop_device_file ];then
                loop_device=$(cat /sys/block/zram0/backing_dev)
                if [ "$loop_device" != "none" ];then
                    losetup -d $loop_device
                    rm -f /data/vendor/swap/zram_wb
                fi
            fi
            echo 1 > /sys/block/zram0/reset
            oppo_configure_zram_parameters

            mkswap /dev/block/zram0
            echo "zwb swapon start" > /dev/kmsg
            swapon /dev/block/zram0 -p 32758
            echo "zwb swapon done" > /dev/kmsg
            ;;
        "1")
            # enable zram writeback
            oppo_zram_disksize=$(cat /sys/block/zram0/disksize)
            # reset zram swapspace
            echo "zwb swapoff start" > /dev/kmsg
            ret=$(swapoff /dev/block/zram0 2>&1)
            if [ $? -ne 0 ];then
                echo "zwb $ret" > /dev/kmsg
                return
            fi
            echo "zwb swapoff done" > /dev/kmsg

            # detaching loop device before reset
            loop_device_file="/sys/block/zram0/backing_dev"
            if [ -f $loop_device_file ];then
                loop_device=$(cat /sys/block/zram0/backing_dev)
                if [ "$loop_device" != "none" ];then
                    losetup -d $loop_device
                fi
            fi

            echo 1 > /sys/block/zram0/reset

            disksize=$(getprop persist.vendor.zwriteback.disksize)
            case $disksize in
                [1-9])
                    disksize="${disksize}M"
                    ;;
                [1-9][0-9]*)
                    disksize="${disksize}M"
                    ;;
                *)
                    disksize="${oppo_zram_disksize}"
                    ;;
            esac

            # check if ZRAM_WRITEBACK_CONFIG enable
            writeback_file="/sys/block/zram0/writeback"
            if [[ -f $writeback_file ]];then
                configure_zram_writeback
                # check if configure_zram_writeback success
                if [ $? -ne 0 ];then
                    disksize="${oppo_zram_disksize}"
                    echo 0 > /sys/block/zram0/mem_limit
                fi
            else
                rm -f /data/vendor/swap/zram_wb
                disksize="${oppo_zram_disksize}"
                echo 0 > /sys/block/zram0/mem_limit
            fi
            echo $disksize > /sys/block/zram0/disksize

            mkswap /dev/block/zram0
            echo "zwb swapon start" > /dev/kmsg
            swapon /dev/block/zram0 -p 32758
            echo "zwb swapon done" > /dev/kmsg
            ;;
        *)
            ;;
    esac

    # final check for consistency
    zwb_now=`getprop persist.vendor.zwriteback.enable`
    if [ "$zwb_switch" == "$zwb_now" ]; then
        retry=0
    fi
}

retry=1
while :
do
    if [ "$retry" == "1" ]; then
        configure_zwb_parameters
    else
        break
    fi
done
#endif /* OPLUS_FEATURE_ZRAM_WRITEBACK */
