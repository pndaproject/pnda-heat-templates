if [[ $1 == "" ]] || [[ $2 != "" ]]; then
    echo "Try  'check-stack.sh --help '  for more information"
    exit -1;
fi

if [[ $1 == "--help" ]] || [[ $1 == "-h" ]]; then
    echo "Usage check-stack.sh <stack-name>"
    echo "Example: check-stack.sh pnda"
    exit -1;
fi

D=$(date)
LOG="$1.stack.log"
echo "$D" > $LOG
IFS=$'\n'

output=$(openstack stack resource list $1 2>&1)

if [[ "$output" =~ "Stack not found" ]]; then
    echo "*** Stack not found: $1"
    echo "*** stack not found: $1" >> $LOG 2>&1
    exit -1;
fi

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

