#!/bin/sh
### BEGIN INIT INFO
# Provides:          mount-cgfs
# Required-Start:    mountkernfs $local_fs $remote_fs
# Required-Stop:
# Should-Start:      udev module-init-tools
# X-Start-Before:
# Default-Start:     S
# Default-Stop:
# Short-Description: Mount cgroups pseudo filesystem
# Description:  Loads kernel parameters that are specified in /etc/sysctl.conf
### END INIT INFO

# Author: Kei Hibino <ex8k.hibino@gmail.com>


PATH=/sbin:/usr/bin:/bin

. /lib/lsb/init-functions

# Include libvirtd defaults if available
if [ -r /etc/default/mount-cgfs ] ; then
    . /etc/default/mount-cgfs
fi

get_cgroups() {
    [ ! -r /proc/cgroups ] || tail -n +2 /proc/cgroups | cut -f 1 | egrep -v memory
}

set_cgroups_var() {
    if [ x"$cgroups" != xNONE ]; then
	[ x"$cgroups" != x ] || cgroups=$(get_cgroups)
    fi
}

systemd_running() {
    if [ -d /run/systemd/system ] ; then
        return 0
    fi
    return 1
}

mount_cgroups() {
    set_cgroups_var

    if ! systemd_running
    then
        mount -t tmpfs cgroup_root /sys/fs/cgroup || return 1
        for M in $cgroups; do
            mkdir /sys/fs/cgroup/$M || return 1
            mount -t cgroup -o rw,nosuid,nodev,noexec,relatime,$M "cgroup_${M}" "/sys/fs/cgroup/${M}" || return 1
        done
    else
        log_warning_msg "Systemd running, skipping cgroup mount."
    fi

}

umount_cgroups() {
    set_cgroups_var

    if ! systemd_running
    then
        for M in $cgroups; do
            umount "cgroup_${M}"
            rmdir /sys/fs/cgroup/$M
        done
        umount cgroup_root
    else
        log_warning_msg "Systemd running, skipping cgroup mount."
    fi
}

case "$1" in
    start)
        log_action_begin_msg "Mounting cgroup filesystems"
        mount_cgroups
        log_end_msg "$?"
        ;;
    stop)
        log_action_begin_msg "Un-mounting cgroup filesystems"
        umount_cgroups
        log_end_msg "$?"
        ;;

    restart|force-reload)
        $0 stop
        $0 start
        ;;

    status)
        mount | egrep /sys/fs/cgroup
        ;;

    *)
        N=/etc/init.d/mount-cgfs
        echo "Usage: $N {start|stop|restart|reload|force-reload}" >&2
        exit 1
        ;;
esac
