#/bin/sh -e

#echo $v
#echo $(jq -r '.variables.template' < mao.ubuntu.LAMP.json)
box_name=${2:-"mao/lamp32"}
echo ${1:+"kuku"} $box_name
