#!/bin/bash
##################################################
# Name: basic-info.sh
# Description: Grabs basic info about the server
# Company: Security Inspection, Inc.
# Script Maintainer: Jacob Amey
#
# Last Updated: July 9th 2013
##################################################
# 
echo "Info about the server:" > /store/docs/Info.txt
echo "##############################" >> /store/docs/Info.txt
uname -a >> /store/docs/Info.txt
echo "##############################" >> /store/docs/Info.txt
cat /etc/sysconfig/network-scripts/ifcfg-eth0 >> /store/docs/Info.txt
echo "##############################" >> /store/docs/Info.txt
route >> /store/docs/Info.txt
echo "##############################" >> /store/docs/Info.txt
