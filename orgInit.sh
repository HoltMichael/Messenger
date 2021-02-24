#!/bin/bash
sfdx force:org:create -f config/project-scratch-def.json -a messengerScratch --setdefaultusername -d 30

sfdx force:source:push 
sfdx force:user:create --setalias secondUser
sfdx force:user:password:generate --targetusername secondUser

sfdx force:user:permset:assign -n Messenger_User

#sfdx force:data:tree:import --plan config/user-def.json

#sfdx force:org:open