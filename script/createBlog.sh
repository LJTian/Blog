#bin/bash

execPath=`pwd`
outPath="${execPath}/../source/_posts/cn/"
mdPath="../mdDir"
tages=`ls ${mdPath}`
for tage in $tages
do
  files=`ls ${mdPath}/$tage`
  for file in $files
  do
    echo $tage-$file
    $execPath/preMd.sh ${execPath}/${mdPath}/${tage}/${file} ${tage} ${tage}
  done
done

mv $execPath/*_blog.md $outPath
