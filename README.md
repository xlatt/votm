# VOTM
votm is program that can be used for governing public or anonymous voting

# HOW TO USE
Votm is listening for commands on two ports.
Commands for creating room and obtainig voting resulst are sent to port 6969 and actual votes from clients are sent to port 1337.
Commands must be sent via HTTP POST. Order of POST fields is irrelevant.
## Create room
If you want to create voting room you have to send HTTP POST with this fields:
###### command
Set to: "cr" which is abbreviation for create room
###### room_type
This can be "pu" which stands for public voting or "pr" and that will set up private or anonymous voting
###### timeout (time period in which will be voting allowed)
Timeout should be in format XXX. Allowed range is <10;999> seconds so for example 20s timeout should be formated this way: 020 
###### participants
List of people attending voting. delimeter between names must be "-"

As response you will recieve HTTP POST response. If everything went according to plan response will containt 200 OK status code and data in format: OKCR<room id><participant=voting_token-...> \
**OKCR** is indicating that command cr was executed successfully. **room id** is repsenting room which was created, you will need it later in two separate occasions so save it. Last field contains list of participants with voting tokens which were assignet to them. This list is separated with "-".

Obtained tokens and room id **must** be redistributed to clients who want to participate in voting. This function is not provided byt this programm.

In case of any error POST with status code 500 is sent specific error code is in POST data. See section **Error codes** for more information on error codes.

## Get voting results
###### command
Set to: "gr" hich is abbreviation for get results
###### room_id
Set to id of room from which you want results

As response you will recieve HTTP POST response. If everything went according to plan response will containt 200 OK status code and data in format: TODO

In case of any error POST with status code 500 is sent specific error code is in POST data. See section **Error codes** for more information on error codes.

## Send vote
###### command
Set to: "rv" which is abbreviation for register vote.
###### room_id
Set to id of room for which you want to send vote.
###### token
Set to token that was assigned to client by some third party.
###### vote
Actual vote. This can be **0** which is representing **NO** vote or **1** which is representing **YES** vote. If client wants to abstain from voting no voting command should be sent.

If everything went according to plan response will containt 200 OK status code  and ERR::OK code as data. In case error POST with status code 500 is sent and specific error code is in POST data. See section **Error codes** for more information on error codes.
## Error codes
	BAD_PARAM_COUNT (ERR101)
	BAD_ROOM_ID (ERR102)
	BAD_ROOM_ID_LEN (ERR103)
	BAD_ROOM_TYPE (ERR104)
	BAD_TIMEOUT_FORMAT (ERR105)
	BAD_TIMEOUT_INTERVAL (ERR106)
	BAD_TOKEN (ERR107)
	BAD_TOKEN_LEN (ERR108)
	BAD_VOTE_VALUE (ERR109)
	MAX_ROOM_COUNT_REACHED (ERR110)
	NOT_ENOUGH_PARTICIPANTS (ERR111)
	ROOM_INACTIVE (ERR112)
	ROOM_STILL_ACTIVE (ERR113)
	UNKNOW_COMMAND (ERR114)
	UNKNOW_FIELD (ERR115)

# TODO
use TLS \
get rid of rjust when generating token/room id \
finish README
