#!/bin/bash
##################################################
# Name: yum-package-list.sh
# Description: This script generates the package list then you can pipe this list into yum.
# Company : Security Inspection, Inc. 
# Script Maintainer: Jacob Amey
#
# Last Updated: July 9th 2013
##################################################
# Simple One Liner
rpm -qa --qf %{NAME}\ > /store/packages/packageLitst.txt
# EOF
