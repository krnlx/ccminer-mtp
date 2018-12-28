#!/usr/bin/zsh
while true; 
do 
date
echo Launching miner

#./ccminer -a x16r -R 1 -i 24 -o  stratum+tcp://rvn.suprnova.cc:6667 -u krnlx.`hostname` -p pass  > log_`hostname`.txt 2> err_`hostname`.txt ;
./ccminer -a mtp -o stratum+tcp://zcoin.mintpond.com:3000 -u aFZGwPK5dAb8i4feQ5WjRjvWhFiMQn8JwZ.`hostname`_2 -i 19 -p x,d=8192,strict -R 30 -r 100  -d 4,5 > log_`hostname`.txt.2 2> err_`hostname`.txt.2 ;

sleep 2
#./ccminer  -a mtp -o stratum+tcp://xzc.2miners.com:8080 -u aFZGwPK5dAb8i4feQ5WjRjvWhFiMQn8JwZ.`hostname` -i 18 -p x -R 30 -r 10 > log_`hostname`.txt 2> err_`hostname`.txt ;

#unbuffer ./ccminer -a mtp -o 192.168.8.2:8382 -u user -p x --coinbase-addr=a7aCo6T5oU3svtHZiPYNpr52qcmokEgJ2J -i 18  --no-getwork > log_`hostname`.txt 2> err_`hostname`.txt ;

done
