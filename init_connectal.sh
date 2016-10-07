#!/bin/bash

mkdir -p tools
cd tools;

#new connectal
git clone https://github.com/cambridgehackers/connectal.git connectal
cd connectal;
git pull;
#git reset --hard d5a9a495
cd ../;

git clone https://github.com/cambridgehackers/fpgamake.git
cd fpgamake;
git pull;
cd ../;


git clone https://github.com/cambridgehackers/buildcache.git
cd buildcache;
git pull;
cd ../;

