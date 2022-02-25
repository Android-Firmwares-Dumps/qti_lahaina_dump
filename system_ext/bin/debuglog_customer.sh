#! /system/bin/sh

CUSTOMER_LOG_PATH_DEFAULT=/data/oplus/log/customerlog

config="$1"

function customerMain() {
    CUSTOMER_LOG_PATH=`getprop persist.sys.log.customer_path`
    if [ "" == "${CUSTOMER_LOG_PATH}" ] || [ ! -d  ${CUSTOMER_LOG_PATH} ]; then
        CUSTOMER_LOG_PATH=${CUSTOMER_LOG_PATH_DEFAULT}
        echo "${CUSTOMER_LOG_PATH}"
        mkdir -p ${CUSTOMER_LOG_PATH}
    fi
    /system/bin/logcat -f ${CUSTOMER_LOG_PATH}/android.txt -r 10240 -n 5 -v threadtime *:V
}

function customerEvent() {
    CUSTOMER_LOG_PATH=`getprop persist.sys.log.customer_path`
    if [ "" == "${CUSTOMER_LOG_PATH}" ] || [ ! -d  ${CUSTOMER_LOG_PATH} ]; then
        CUSTOMER_LOG_PATH=${CUSTOMER_LOG_PATH_DEFAULT}
        mkdir -p ${CUSTOMER_LOG_PATH}
    fi
    /system/bin/logcat -b events -f ${CUSTOMER_LOG_PATH}/event.txt -r 10240 -n 5 -v threadtime *:V
}

function customerRadio() {
    CUSTOMER_LOG_PATH=`getprop persist.sys.log.customer_path`
    if [ "" == "${CUSTOMER_LOG_PATH}" ] || [ ! -d  ${CUSTOMER_LOG_PATH} ]; then
        CUSTOMER_LOG_PATH=${CUSTOMER_LOG_PATH_DEFAULT}
        mkdir -p ${CUSTOMER_LOG_PATH}
    fi
    /system/bin/logcat -b radio -f ${CUSTOMER_LOG_PATH}/radio.txt -r 10240 -n 5 -v threadtime *:V
}

function customerKernel() {
    CUSTOMER_LOG_PATH=`getprop persist.sys.log.customer_path`
    if [ "" == "${CUSTOMER_LOG_PATH}" ] || [ ! -d  ${CUSTOMER_LOG_PATH} ]; then
        CUSTOMER_LOG_PATH=${CUSTOMER_LOG_PATH_DEFAULT}
        mkdir -p ${CUSTOMER_LOG_PATH}
    fi
    dmesg > ${CUSTOMER_LOG_PATH}/dmesg.txt
    /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${CUSTOMER_LOG_PATH}/kernel.txt | awk 'NR%400==0'
}

function customerTcpdump() {
    CUSTOMER_LOG_PATH=`getprop persist.sys.log.customer_path`
    if [ "" == "${CUSTOMER_LOG_PATH}" ] || [ ! -d  ${CUSTOMER_LOG_PATH} ]; then
        CUSTOMER_LOG_PATH=${CUSTOMER_LOG_PATH_DEFAULT}
        mkdir -p ${CUSTOMER_LOG_PATH}
    fi
    tcpdump -i any -p -s 0 -W 1 -C 50 -w ${path}/tcpdump.pcap
}

case "$config" in
    "customer_main")
        customerMain
        ;;
    "customer_event")
        customerEvent
        ;;
    "customer_radio")
        customerRadio
        ;;
    "customer_kernel")
        customerKernel
        ;;
    "customer_tcpdump")
        customerTcpdump
        ;;
    *)
        ;;
esac