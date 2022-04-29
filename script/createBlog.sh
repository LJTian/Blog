#bin/bash

execPath=`pwd`
outPath="${execPath}/../source/_posts/cn/"
mdPath="../mdDir"
tages=`ls ${mdPath}`
for tage in $tages
do
  files=`ls ${mdPath}/$tage | grep -v _blog `
  for file in $files
  do
    echo $tage-$file
    name=`echo "${file}" | awk -F '.' '{print $1}'`
    #$execPath/preMd.sh ${execPath}/${mdPath}/${tage}/${file} ${tage} ${tage}
    cp ${execPath}/${mdPath}/${tage}/${name}_blog.md $execPath/
    cat ${execPath}/${mdPath}/${tage}/${file} >> $execPath/${name}_blog.md
  done
done

mv $execPath/*_blog.md $outPath
