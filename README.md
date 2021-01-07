# Various scripts for supporting customers


---
## collect-vm-template-files-and-folders.bash

```
❯ oldIFS=$IFS; IFS=$'\n'; for i in $(./collect-vm-template-files-and-folders.bash 10.15.7-xcode11.7-webkit); do echo "test: $i"; done; IFS=$oldIFS 
test: /Users/nathanpierce/Library/Application Support/Veertu/Anka/img_lib/746be7a6103e4f9481f3f9a99756d6fd.ank
test: /Users/nathanpierce/Library/Application Support/Veertu/Anka/img_lib/901212c557b94d9db79e510aaeb3c21c.ank
test: /Users/nathanpierce/Library/Application Support/Veertu/Anka/vm_lib/b1b9d901-2b87-410f-99bf-82411416d0b2
```

Transfer all files and folders with rsync:

```
set -x
pushd "$(anka config vm_lib_dir)/.." && BASE_PATH=$(pwd)
oldIFS=$IFS; IFS=$'\n'; for path in $($HOME/collect-vm-template-files-and-folders.bash 10.15.7-xcode11.7-webkit); do
FULL_PATH=$path
path=$(echo $path | sed "s/$(echo $BASE_PATH | sed 's/\//\\\//g')\///g")
rsyncOpts=""
dest=${FULL_PATH// /\\ }
if [[ -d "$path" ]]; then 
	rsyncOpts="--recursive"
	dest="$(echo ${FULL_PATH// /\\ } | rev | cut -d/ -f2-99 | rev)"
fi
ssh -o StrictHostKeyChecking=no -i "/Users/administrator/.ssh/perf-test" administrator@{IP} "mkdir -p $(echo ${FULL_PATH// /\\ } | rev | cut -d/ -f2-99 | rev)"
rsync -avzP $rsyncOpts -e 'ssh -i /Users/administrator/.ssh/perf-test -o StrictHostKeyChecking=no' $path administrator@{IP}:$dest
done; IFS=$oldIFS
set +x
popd
```