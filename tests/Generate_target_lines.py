#!/usr/bin/python3

import sys

filein = open(sys.argv[1], 'r')
fileout = open(sys.argv[2], 'w')
wordCounts={}
count = 20
line=filein.readline()
while line :
    word = line.rpartition("/")[2]
    if word in wordCounts :
    	wordCounts[word] += 1
    else:
    	wordCounts[word] = 1
    line=filein.readline()
items0 = list(wordCounts.items())
items = [[x,y] for (y,x) in items0]
items.sort()
if count > len(items):
	count = len(items)
maxCount = items[len(items)-1][0]
for i in range(len(items)-1, len(items)-count-1, -1):
	if (items[i][0]*10 < maxCount):
		continue;
	else:
		print(str(items[i][0]) + '\t' + items[i][1], end="")
		fileout.write(items[i][1])
filein.close()
fileout.close()
    	
    	
