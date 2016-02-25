#/bin/sh -e
if [ -e builds/latest  ]
then 
	rm builds/latest
fi

lastdir=`ls builds | tail -1`
ln -s ${lastdir} builds/latest

# vagrant box add --name mao/lamp32 builds/${lastdir}/u14-x86-LAMP.virtualbox.box --box-version "${lastdir//-/.}"
vagrant box add --force --name mao/lamp32 builds/${lastdir}/u14-x86-LAMP.virtualbox.box