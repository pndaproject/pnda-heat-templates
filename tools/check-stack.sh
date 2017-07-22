D=$(date)
LOG="$1.stack.log"
echo "$D" > $LOG
IFS=$'\n'
stacks=$(openstack stack list --nested | grep $1)
for stackline in $stacks; do echo $stackline >> $LOG 2>&1; done
for stackline in $stacks
do
    stack=$(echo $stackline | awk '{print $4}')
    echo "*** stack $stack"
    echo "*** stack $stack" >> $LOG 2>&1
    resources=$(openstack stack resource list $stack)
    for resourceline in $resources; do echo $resourceline >> $LOG 2>&1; done
    for resourceline in $resources
    do
        rname=$(echo $resourceline | awk '{print $2}')
        if [[ -z "$rname" ]] || [[ "$rname" == "resource_name" ]]; then continue; fi
        ruid=$(echo $resourceline | awk '{print $4}')
        rtype=$(echo $resourceline | awk '{print $6}')
        rstatus=$(echo $resourceline | awk '{print $8}')
        echo "*** stack $stack resource $rname"
        # for performance reasons don't resource show things that are complete
        if [[ "$rstatus" != "CREATE_COMPLETE" ]]; then
            echo "*** stack $stack resource $rname show" >> $LOG 2>&1
            openstack stack resource show $stack $rname -f yaml >> $LOG 2>&1
        fi
        # but always dump deployment debug as problems don't always cause resource failures
        if [[ "$rtype" == "OS::Heat::SoftwareDeployment" ]]; then
            echo "*** stack $stack resource $rname deployment output show" >> $LOG 2>&1
            openstack software deployment output show --all $ruid --long >> $LOG 2>&1
        fi
    done
done

