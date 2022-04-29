#bin/bash

execPath=`pwd`
date=`date '+%Y-%m-%d %H:%M:%S'`
name=`echo "${1}" | awk -F '.' '{print $1}'`
newName=${name}_blog.md

echo "---
title: $name
catalog: true
date: $date
subtitle:
header-img: /img/header_img/$name.jpg
tags:
- $2
categories:
- $3
---
" > ${newName}

