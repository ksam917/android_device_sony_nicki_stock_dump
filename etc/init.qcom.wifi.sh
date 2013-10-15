#!/system/bin/sh
# Copyright (c) 2010-2012, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of The Linux Foundation nor the names of its
#       contributors may be used to endorse or promote products derived
#      from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# This script will load and unload the wifi driver to put the wifi in
# in deep sleep mode so that there won't be voltage leakage.
# Loading/Unloading the driver only incase if the Wifi GUI is not going
# to Turn ON the Wifi. In the Script if the wlan driver status is
# ok(GUI loaded the driver) or loading(GUI is loading the driver) then
# the script won't do anything. Otherwise (GUI is not going to Turn On
# the Wifi) the script will load/unload the driver
# This script will get called after post bootup.

target="$1"
serialno="$2"

btsoc=""

# No path is set up at this point so we have to do it here.
PATH=/sbin:/system/sbin:/system/bin:/system/xbin
export PATH

# Load wifi kernel module
load_wifiKM()
{
    # We need to make sure the WCNSS platform driver is running.
    # The WCNSS platform driver can either be built as a loadable
    # module or it can be built-in to the kernel.  If it is built
    # as a loadable module it can have one of several names.  So
    # look to see if an appropriately named kernel module is
    # present
    wcnssmod=`ls /system/lib/modules/wcnss*.ko` 2> /dev/null
    case "$wcnssmod" in
        *wcnss*)
            # A kernel module is present, so load it
            insmod $wcnssmod
            ;;
        *)
            # A kernel module is not present so we assume the
            # driver is built-in to the kernel.  If that is the
            # case then the driver will export a file which we
            # must touch so that the driver knows that userspace
            # is ready to handle firmware download requests.  See
            # if an appropriately named device file is present
            wcnssnode=`ls /dev/wcnss*`
            case "$wcnssnode" in
                *wcnss*)
                    # There is a device file.  Write to the file
                    # so that the driver knows userspace is
                    # available for firmware download requests
                    echo 1 > $wcnssnode
                    ;;
                *)
                    # There is not a kernel module present and
                    # there is not a device file present, so
                    # the driver must not be available
                    echo "No WCNSS module or device node detected"
                    ;;
            esac
            ;;
    esac

    # Plumb down the device serial number
    if [ -f /sys/devices/*wcnss-wlan/serial_number ]; then
        cd /sys/devices/*wcnss-wlan
        echo $serialno > serial_number
        cd /
    elif [ -f /sys/devices/platform/wcnss_wlan.0/serial_number ]; then
        echo $serialno > /sys/devices/platform/wcnss_wlan.0/serial_number
    fi
}


case "$target" in
    msm8960*)

      wlanchip=""

      echo "The WLAN Chip ID is $wlanchip"
      case "$wlanchip" in
      *)
        echo "*** WI-FI chip ID is not specified in /persist/wlan_chip_id **"
        echo "*** Use the default WCN driver.                             **"
        setprop wlan.driver.ath 0 

        # The property below is used in Qcom SDK for softap to determine
        # the wifi driver config file
        setprop wlan.driver.config /data/misc/wifi/WCNSS_qcom_cfg.ini
        
        # write mac from ta file
        wifimac -w &

        # write BT addr from ta file
        BT_addr &

        # Load kernel module in a separate process
        load_wifiKM &
        ;;
      esac
      ;;
    *)
      ;;
esac

# Run audio init script
/system/bin/sh /system/etc/init.qcom.audio.sh "$target" "$btsoc"
