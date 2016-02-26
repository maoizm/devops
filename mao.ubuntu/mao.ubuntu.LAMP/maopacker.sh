#/bin/sh -e

#
# usage:  maopacker <packer template file> <vagrant box name>
#

if ! packer build $1 ; then
    printf '%s\n' 'maopacker: Error in packer' >&2
    exit 1
fi

# delete all files and symlinks in builds/ directory non-recursively
find builds -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -delete

# finds the last directory ordered by date and time 
latest_dir=$(ls -d builds/*/ | cut -f2 -d'/' | tail -1)

# symlinks all files in builds/latest_dir/ directory to builds/ non-recursively
find builds/$latest_dir/ -mindepth 1 -maxdepth 1 -type f | cut -f3 -d'/' | xargs -I filename ln -s $latest_dir/filename builds/filename

# vagrant box add --name mao/lamp32 builds/latest/u14-x86-LAMP.virtualbox.box --box-version "${lastdir//-/.}"


# find VM template string from packer json template and removes trailing newlines
template=$(jq -r '.variables.template' < $1)
template="$(echo -e "${template}" | sed -e 's/[[:space:]]*$//')"
box_name=${2:-"mao/lamp32"}

if ! vagrant box add --force --name $box_name builds/$template.virtualbox.box ; then
    printf '%s\n' 'maopacker: Error in vagrant' >&2
	printf '%s%s%s%s%s\n' 'maopacker: Command: vagrant box add --force --name ' $box_name ' builds/' $template '.virtualbox.box' >&2
    exit 2
fi
