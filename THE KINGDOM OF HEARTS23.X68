;-------------------------------------------------------
; 68000 Assembly Game – Kingdom of Hearts
; Module: Assembly and C Programming
; Year 2 Stage 2 – Software Development and Cyber Security
;
; Student Name: Lucas Gabriel De Oliveira Lima
; Student ID: C00298828
; Date Created: FEB 2026
;
; Description:
; This project is a text-based adventure game written in
; Motorola 68000 assembly language using Easy68K.
; The player chooses a character (Growler or Stray) and
; progresses through seven days of story events.
; Each day the player can explore, rest, prepare or inspect
; their status. Random events affect health, bravery and
; inventory. On the final day the player fights the Lion King
; in a boss battle using attack, defend or potion actions.
;
; Known Bugs / Limitations:
; No known critical bugs. Gameplay balance depends on RNG.
;-------------------------------------------------------


*-------------------------------------------------------
* STARTING MEMORY ADDRESS FOR THE PROGRAMME $1000
*-------------------------------------------------------
	ORG $1000 ;ORIGIN STARTS FROM 1000
*-------------------------------------------------------
*CHOOSE TO BE THE GROWLER OR STRAY

*-------------------------------------------------------

*-------------------------------------------------------
*VALIDATION VALUES 
*-------------------------------------------------------
EXIT		EQU 0			;USED TO EXIT ASSEMBLY PROGRAM
MIN_POTIONS	EQU 1			;MIN NUMBER OF SMALL POTIONS
MAX_POTIONS	EQU 9			;MAX NUMBER OF SMALL POTIONS
MIN_WEAPONS	EQU 1			;MIN WEAPONS (NEEDLE SWORD, ACORN SHIELD)
MAX_WEAPONS	EQU 3			;MAX WEAPONS
WIN_POINT	EQU 5			;BRAVERY POINTS GAINED ON SUCCESS
LOSE_POINT	EQU 8			;BRAVERY POINTS LOST ON FAILURE
FINAL_DAY   EQU 7           ;FINAL EVENT HAPPENS WHEN GAME HITS FINAL DAY

DANGER_LOC  EQU 100         ;USED FOR SIMPLE COLLISION DETECTION
                            ;* EXAMPLE FOR A HIT (GIANT FOOTSTEP)

*-------------------------------------------------------
*-------------------START OF THE GAME---------------------
*-------------------------------------------------------
START:
    MOVE.B  #100,$4000      ;PUT BRAVERY POINTS IN MEMORY LOCATION $4000
    LEA     $4000,A3        ;ASSIGN ADDRESS A3 TO THAT MEMORY LOCATION
    BSR     WELCOME         ;BRANCH TO THE WELCOME SUBROUTINE
    BSR     GAME            ;BRANCH TO THE GAME SUBROUTINE

*GAME LOOP
    ORG     $3000           ;THE REST OF THE PROGRAM IS TO BE LOCATED FROM 3000 ONWARDS
    
*-------------------------------------------------------
*------------------------END OF MAIN GAME SECTION--------
*-------------------------------------------------------   

*-------------------------------------------------------
*-------------------START OF MAIN GAME CONTROLS---------------------
*-------------------------------------------------------
GAME:
   BSR  INITGAME        ;CALLS INITGAME SUBROUTINE
   BSR  CHOOSE_CHAR     ;CALLS CHOOSE_CHAR SUBROUTINE
   BSR  INPUT           ;INPUT FOR LOADOUT

MAIN_TURN:
    BSR TURN    ;One day / One Mission
    BSR HUD     ;SMALL HUD WITH STATUS OF THE PLAYER
    BSR CHECK_GAMEOVER  ;CHECKS IF GAME HAS REACHED GAMEOVER CONDITION
    BSR REPLAY  ;ASK TO QUIT OR CONTINUE
    BRA MAIN_TURN

INITGAME:
    MOVE.B  #$FF, LAST_EVENT ;Stops first event of re-rolling unexpectaly 
    MOVE.W  #1,DAY      
    MOVE.B  #1,DIFFICULTY   ;DAY 1=DIFFICULTY LEVEL 1
    MOVE.W  #1234,RNG_SEED  ;ANY non-zero seed
    MOVE.W  #100,HEALTH     ;starting health
    RTS

*-------------------------------------------------------
*------------------------TURN(MISSON SETTINGS)----------
*-------------------------------------------------------

TURN:
    BSR CLEAR_SCREEN
    BSR UPDATE
    BSR DRAW
    BSR STORY_BEAT
    BSR DAY_MENU

    ; If final day, do boss
    CMP.W   #FINAL_DAY,DAY
    BEQ     BOSS_DAY

    ; Progress to next day
    ADD.W   #1,DAY
    ADD.B   #1,DIFFICULTY
    RTS

DAY_MENU:   
MENU_SHOW:
    BSR ENDL
    LEA DAY_MENU_MSG,A1 ;PRINT MESSAGE WITH MENU FOR PLAYER, SHOWS WHICH DAY PLAYER IS 1...2...3
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    LEA OPT1_MSG,A1     ;CYCLE THROUGH MENU OPTIONS(EXPLORE)
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    LEA OPT2_MSG,A1     ;(PREPARE
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    LEA OPT3_MSG,A1     ;(TRAIN/USE POTION)
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    LEA OPT0_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    ;               read choice by number
    MOVE.B #4,D0
    TRAP #15        ;D1 = input

                    ;0 = inspect (optional)
    CMP.B #0,D1
    BEQ DO_INSPECT

                    ;choice validation 1..3
    CMP.B #1,D1
    BLT MENU_BAD
    CMP.B #3,D1
    BGT MENU_BAD

    CMP.B #1,D1
    BEQ DO_EXPLORE
    CMP.B #2,D1
    BEQ DO_REST
                    ;else goes to 3 and prepare for mission
    BRA DO_PREPARE

DO_EXPLORE:
    BSR ENDL
    LEA EXPLORE_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    BSR RAND100          ;CALLS RANDOM SUBROUTINE D1;1...99

    CMP.W #40,D1
    BLT EXP_LOOT
    CMP.W #75,D1
    BLT EXP_HURT
    BRA EXP_NOTHING

;-------------------------
; Loot: chance to get extra potion
;-------------------------
EXP_LOOT:
    LEA LOOT_MSG,A1
    MOVE.B #14,D0
    TRAP #15
;-------------------------
; WEIGHT MANAGER
;-------------------------
                                
    MOVE.B CURRENT_WEIGHT,D2
    ADD.B  #1,D2
    CMP.B  MAX_WEIGHT,D2
    BGT EXP_NO_SPACE

    
    MOVE.B D2,CURRENT_WEIGHT
    ADD.B  #1,POTION_CNT
                                ;ADDs a weight condition:  if (CURRENT_WEIGHT + 1) > MAX_WEIGHT -> no space
    BSR ENDL
    LEA GAIN_POTION_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS

EXP_NO_SPACE:
    BSR ENDL
    LEA NO_SPACE_MSG,A1         
    MOVE.B #14,D0
    TRAP #15
    RTS

;-------------------------
; Hurt: -5 health, -2 bravery
;-------------------------
EXP_HURT:
    LEA HURT_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    MOVE.W  #5,D2
    BSR SCALE_DMG
    SUB.W   D2,HEALTH

    MOVE.B (A3),D7
    SUB.B #2,D7
    MOVE.B D7,(A3)

    BSR ENDL
    LEA HURT_RESULT_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS

;-------------------------
; Nothing: +1 bravery
;-------------------------
EXP_NOTHING:
    LEA NOTHING_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    MOVE.B (A3),D7
    ADD.B #1,D7
    MOVE.B D7,(A3)

    BSR ENDL
    LEA NOTHING_RESULT_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS
;-------------------------
; REST OPTION: +8 health
;-------------------------    
DO_REST:
    BSR ENDL
    LEA REST_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    ADD.W #8,HEALTH

;-------------------------
; RANDOM EVENT; CHANCE OF LOSING BRAVERY
;-------------------------

    ;20% to lose bravery
    BSR RAND100
    CMP.W #20,D1
    BGE REST_OK

    MOVE.B (A3),D7
    SUB.B #1,D7
    MOVE.B D7,(A3)

    BSR ENDL
    LEA REST_DOWN_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS

REST_OK:
    BSR ENDL
    LEA REST_OK_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS    
;-------------------------
; PREPARE FOR MISSION: -1 POTION
;-------------------------
DO_PREPARE:
    BSR ENDL
    LEA PREPARE_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    TST.B POTION_CNT
    BEQ PREP_NO_POTION

    SUB.B #1,POTION_CNT

    MOVE.B (A3),D7
    ADD.B #3,D7
    MOVE.B D7,(A3)

    BSR ENDL
    LEA PREP_OK_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS
;-------------------------
; PREPARE FOR MISION: NO POTION ? FAIL AND -BRAVERY
;-------------------------
PREP_NO_POTION:
    MOVE.B (A3),D7
    SUB.B #1,D7
    MOVE.B D7,(A3)

    BSR ENDL
    LEA PREP_FAIL_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS

*-------------------------------------------------------
*------------------------CHECK GAME OVER----------
*-------------------------------------------------------


CHECK_GAMEOVER:
                        ;if health <= 0 OR bravery <= 0 => end
    MOVE.W HEALTH, D1
    BLE DO_GAMEOVER

    MOVE.B  (A3),D1
    BLE DO_GAMEOVER

    RTS
    
DO_GAMEOVER:
    BSR ENDL
    LEA GAMEOVER_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

;-------------------------
; GAME OVER BRANCHES: SIDE STORIES 
;-------------------------

    ; Ending 
    MOVE.B CHAR_CHOICE,D1
    CMP.B #1,D1
    BEQ DEATH_GROWLER_END
    BRA DEATH_STRAY_END

DEATH_GROWLER_END:
    LEA END_GROWLER_LOSE_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BRA GAME_END

DEATH_STRAY_END:
    LEA END_STRAY_LOSE_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BRA GAME_END


GAME_END:
    SIMHALT


*-------------------------------------------------------
*------------------------END OF MAIN GAME SECTION-------
*-------------------------------------------------------



*-------------------------------------------------------
*-------------------WELCOME SUBROUTINE------------------
*-------------------------------------------------------
WELCOME:
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    LEA     WELCOME_MSG,A1  ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    RTS                     ;RETURN FROM WELCOME: SUBROUTINE

;-------------------------
;PRESS ANY KEY TO CONTINUE
;-------------------------
PRESS_ANY_KEY:              ;PRESS ANY KEY SUBROUTINE
    BSR ENDL
    LEA PRESSKEY_MSG,A1     ;PRINTS MESSAGE PRESS ANY KEY
    MOVE.B #14,D0
    TRAP #15

    MOVE.B #4,D0
    TRAP #15

    BSR ENDL
    RTS

*-------------------------------------------------------
*------------------- START OF INPUT VALIDATION SECTION--------------------
*-------------------------------------------------------

;-------------------------
;CHOOSE_CHAR:GROWLER OR STRAY
;-------------------------

CHOOSE_CHAR:
ASK_CHAR:
    BSR ENDL
    LEA     CHAR_PROMPT,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.B  #4,D0   ;READ NUMBER
    TRAP    #15     ;D1=INPUT
    
    CMP.B   #1,D1
    BLT CHAR_BAD
    CMP.B   #2,D1
    BGT CHAR_BAD
    
    MOVE.B D1,CHAR_CHOICE ;STORE CHOICE
    
    CMP.B   #1,D1
    BEQ IS_DOG
    BRA IS_CAT
    

;-------------------------
;DOG=GROWLER
;-------------------------    
    
IS_DOG:
    BSR ENDL            
    MOVE.B  #10,MAX_WEIGHT  ;GROWLER GETS A SMALL BONUS ON WEIGHT
    LEA DOG_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15

                               ;GROWLER BONUS: more health
    ADD.W   #20,HEALTH
    RTS

;-------------------------
;CAT=STRAY
;-------------------------
IS_CAT:
    BSR ENDL
    MOVE.B  #6,MAX_WEIGHT       ;STANDARD WEIGHT CARRY FOR STRAY
    LEA CAT_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15

                        ;STRAY BONUS: Speed
    MOVE.B  (A3),D2
    ADD.B   #10,D2
    MOVE.B  D2,(A3)
    RTS

;-------------------------
;IF WRONG KEY IS PRESSED:INVALID KEY PRESSED
;-------------------------
CHAR_BAD:
    LEA INVALID_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    BRA ASK_CHAR    


*-------------------------------------------------------
*---------GAMEPLAY INPUT VALUES SUBROUTINE--------------
*-------------------------------------------------------
INPUT:
    BSR     POTIONS         ;BRANCH TO POTION INPUT SUBROUTINE
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    BSR     CONTINUE        ;BRANCH TO CONTINUE SUBROUTINE
    BSR     WEAPONS         ;BRANCH TO WEAPONS INPUT SUBROUTINE
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    BSR     CONTINUE        ;BRANCH TO CONTINUE SUBROUTINE
    RTS

*-------------------------------------------------------
*----------------GAMELOOP (MAIN LOOP)-------------------
*-------------------------------------------------------
GAMELOOP:
    BSR     INPUT           ;BRANCH TO INPUT SUBROUTINE
    BSR     UPDATE          ;BRANCH TO UPDATE GAME SUBROUTINE
    ;BSR     CLEAR_SCREEN    ;CLEARS THE SCREEN
    BSR     DRAW            ;BRANCH TO DRAW GAME SUBROUTINE
    ;BSR     CLEAR_SCREEN    ;CLEARS THE SCREEN
    BSR     GAMEPLAY        ;BRANCH TO GAMEPLAY SUBROUTINE
    ;BSR     CLEAR_SCREEN    ;CLEARS THE SCREEN
    BSR     HUD             ;BRANCH TO HUD SUBROUTINE
    ;BSR     CLEAR_SCREEN    ;CLEARS THE SCREEN
    BSR     REPLAY          ;BRANCH TO REPLAY SUBROUTINE
    BSR     CLEAR_SCREEN    ;CLEARS THE SCREEN
    RTS                     ;RETURN FROM GAMELOOP: SUBROUTINE

*-------------------------------------------------------
*----------------UPDATE QUEST PROGRESS------------------
*  COMPLETE QUEST
*-------------------------------------------------------
UPDATE:
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
 ;   BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    LEA     UPDATE_MSG,A1   ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
   ; BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    RTS

*-------------------------------------------------------
*-----------------DRAW QUEST UPDATES--------------------
* DRAW THE GAME PROGRESS INFORMATION, STATUS REGARDING
* QUEST
*-------------------------------------------------------
DRAW:
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
  ;  BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    LEA     DRAW_MSG,A1     ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
;    BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    RTS                     ;RETURN FROM DRAW: SUBROUTINE

*-------------------------------------------------------
*--------------------POTIONS INVENTORY---------------------
* NUMBER OF POTIONS TO BE USED IN A QUEST
*-------------------------------------------------------
POTIONS:
ASK_POT:
   
    BSR ENDL
    LEA POTIONS_MSG,A1
    MOVE.B #14,D0
    TRAP   #15

    MOVE.B  #4,D0   ;READ NUMBER
    TRAP    #15     ;D1=input

;-------------------------
; MAX AND MIN AMOUNT OF POTIONS
;-------------------------  

    CMP.B   #MIN_POTIONS,D1
    BLT     POT_BAD
    CMP.B   #MAX_POTIONS,D1
    BGT     POT_BAD
    
    MOVE.B  D1, CURRENT_WEIGHT
    MOVE.B  CURRENT_WEIGHT, D2
    CMP.B   MAX_WEIGHT, D2
    BGT POT_BAD

    MOVE.B  D1,POTION_CNT

    LEA     POTION_OK_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15

    MOVE.B  POTION_CNT,D1
    MOVE.B  #3,D0
    TRAP    #15
    RTS

;-------------------------
; NO POTIONS ? INVALID
;-------------------------  

POT_BAD:
    LEA INVALID_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    BRA     ASK_POT

*-------------------------------------------------------
*-------------------------WEAPONS-----------------------
*-------------------------------------------------------

;-------------------------
; SHOW WEAPONS LIST
;-------------------------  

WEAPONS:
ASK_WEP:
    BSR ENDL
    MOVE.B  #14,D0
    TRAP    #15

    BSR ENDL
    LEA WEAPONS_LIST,A1
    MOVE.B  #14,D0
    TRAP    #15


;-------------------------
; PRESS ENTER 1-3 TO CHOOSE WEAPON
;-------------------------  

    BSR ENDL
    LEA PROMPT_MISS,A1     ;"ENTER 1-3"
    MOVE.B  #14,D0
    TRAP    #15

    MOVE.B  #4,D0
    TRAP    #15

    CMP.B   #MIN_WEAPONS,D1
    BLT WEP_BAD
    CMP.B   #MAX_WEAPONS,D1
    BGT WEP_BAD
    MOVE.B  D1,WEAPON_CHOICE

    LEA WEAPON_OK_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    MOVE.B  WEAPON_CHOICE,D1
    MOVE.B  #3,D0
    TRAP    #15
    RTS

;-------------------------
; INVALID OPTION ? ERROR
;-------------------------  

WEP_BAD:
    LEA INVALID_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    BRA ASK_WEP

    BSR ENDL



*-------------------------------------------------------
*---GAME PLAY (QUEST PROGRESS)--------------------------
*-------------------------------------------------------
GAMEPLAY:
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
  ;  BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    LEA     GAMEPLAY_MSG,A1 ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    
    BSR     ENDL ;PRINTS NEXT LINE EVENT
  ;  MOVE.B  #4,D0           ;MOVE LITERAL 4 TO DO
 ;   TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
   ; BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    BSR     COLLISION       ;BRANCH TO COLLISION SUBROUTINE
    RTS                     ;RETURN FROM GAMEPLAY: SUBROUTINE


*-------------------------------------------------------
*------------------------REPLAY-------------------------
*-------------------------------------------------------
REPLAY:
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    LEA     REPLAY_MSG,A1   ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0

    MOVE.B  #4,D0           ;MOVE LITERAL 4 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0

    CMP     #EXIT,D1        ;COMPARE D1 TO EXIT
    BEQ     GAME_END        ;IF EQUAL, BRANCH TO END
    RTS                     ;PREVENT FALL-THROUGH INTO CONTINUE

*-------------------------------------------------------
*------------------------CONTINUE-------------------------
*-------------------------------------------------------
CONTINUE:
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    LEA     CONTINUE_MSG,A1 ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0

    MOVE.B  #4,D0           ;MOVE LITERAL 4 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    RTS                     ;RETURN FROM SUBROUTINE

ENDL:
    MOVEM.L D0/A1,-(A7)     ;SAVE D0 AND A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    LEA     CRLF,A1         ;ASSIGN CRLF TO ADDRESS REGISTER A1
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    MOVEM.L (A7)+,D0/A1     ;RESTORE D0 AND A1
    RTS                     ;RETURN FROM ENDL: SUBROUTINE




*-------------------------------------------------------
*--------------END OF  INPUTS/VALIDATION SECTION--------
*-------------------------------------------------------





*-------------------------------------------------------
*--------------UI HELPERS-------------------------------
*-------------------------------------------------------

;-------------------------
; PRINT LINE:SEPARES LINES
;-------------------------  

PRINT_LINE:
    ; prints a separator line
    LEA SEP_LINE,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL
    RTS

;---------------------------
;PRINT DAY TYILE: DAY1...DAY2
;---------------------------  

PRINT_DAY_TITLE:
                ; PULLS DAY DATA OF memory, prints: === DAY X ===
    BSR ENDL
    BSR PRINT_LINE

    LEA DAY_TITLE_A,A1      ; "=== DAY "
    MOVE.B #14,D0
    TRAP #15

    MOVE.W DAY,D1
    MOVE.B #3,D0
    TRAP #15

    LEA DAY_TITLE_B,A1      ; " ==="
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL
    
    
    LEA DIFF_MSG,A1
    MOVE.B  #14,D0 ; ADD MESSAGE SO PLAYER CAN SEE INCRASING DIFFICULTY
    TRAP #15
    
    MOVE.B DIFFICULTY, D1
    MOVE.B #3,D0
    TRAP #15
    BSR ENDL    ;ADD A LINE SEPARATOR BETWEEN DIFFICULTY LEVEL AND TEXT DESCRIPTION
    
    BSR PRINT_LINE
    RTS

*-------------------------------------------------------
*-----------------HEADS UP DISPLAY (SCORE)--------------
*-------------------------------------------------------
HUD:
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    
    LEA     HUD_MSG,A1      ;ASSIGN MESSAGE TO ADDRESS REGISTER A1 ;BRAVERY address register
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    MOVE.B  (A3),D1         ;RETRIEVE THE VALUE A3 POINT TO AND MOVE TO D1
    MOVE.B  #3,D0           ;MOVE LITERAL 3 TO DO
    TRAP    #15
    BSR     ENDL
    
    LEA HEALTH_MSG,A1   
    MOVE.B  #14,D0
    TRAP    #15
    MOVE.W  HEALTH,D1
    MOVE.B  #3,D0
    TRAP    #15
    BSR ENDL
    
    LEA     POT_MSG,A1  ; SHOWS HUD FOR PLAYER AFTER EACH TURN
    MOVE.B  #14,D0
    TRAP    #15
    MOVE.B  POTION_CNT,D1
    MOVE.B  #3,D0
    TRAP    #15
    BSR ENDL    ;SPACE BETWEEN LINES
    
    
    BSR     DECORATE        ;BRANCH TO DECORATE SUBROUTINE
    RTS



*-------------------------------------------------------
*-----------------END OF UI HELPERS SECTION--------------
*-------------------------------------------------------



*-------------------------------------------------------
*-----------------------START OF GAMEPLAY LOGIC SECTION-
*-------------------------------------------------------


;-------------------------
; COLLISION: REPRESENTS RANDOM EVENTS
;-------------------------  
COLLISION:

   BSR  RAND100
   CMP.W    #1,D1
   BEQ  LEGEND_EVENT
   BRA  COLLISION_NORMAL

LEGEND_EVENT:
    LEA LEGEND_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    ADD.W #20,HEALTH
    ADD.B #10,(A3)
    RTS

COLLISION_NORMAL:
    BSR RAND100

;-------------------------
;GAME EVENTS 0-3(REPEAT PREVENTION SECTION)
;-------------------------      
    
EV0:
    MOVE.B  #0,D2
    BRA CHECK_REPEAT   
EV1:
    MOVE.B  #1,D2
    BRA CHECK_REPEAT
EV2:
    MOVE.B  #2,D2
    BRA CHECK_REPEAT
EV3:
    MOVE.B  #3,D2


;------------------------------------------------------
 ;CHECKS IF EVENT HAS ALREADY HAPPENED, IF YES, RE-ROLLL
;------------------------------------------------------
CHECK_REPEAT:
    CMP.B   LAST_EVENT,D2
    BNE SET_EVENT
                       
    BSR RAND100
    CMP.W   #25,D1
    BLT EV0B
    CMP.W   #50,D1
    BLT EV1B
    CMP.W   #75,D1
    BLT EV2B
    BRA EV3B

;-------------------------
;CHECKS FOR FALL THROUGH
;-------------------------
EV0B:   MOVE.B  #0,D2   ;FALL THROUGH
        BRA SET_EVENT
EV1B:   MOVE.B  #1,D2
        BRA SET_EVENT
EV2B:   MOVE.B  #2,D2
        BRA SET_EVENT
EV3B:   MOVE.B  #3,D2
        BRA SET_EVENT


;-------------------------
;EVENTS HIT OR MISS
;-------------------------

SET_EVENT:
    MOVE.B  D2,LAST_EVENT
    
    ;EVENT DISPATCH
    CMP.B   #0,D2
    BEQ COLLISION_HIT
    CMP.B   #1,D2
    BEQ COLLISION_MISS
    CMP.B   #2,D2
    BEQ EVENT2
    CMP.B   #3, D2
    BEQ EVENT3
    BRA EVENT4
    
EVENT2:
    LEA EVENT2_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15

    MOVE.B  (A3),D7
    SUB.B   #1,D7
    MOVE.B  D7,(A3)

;-------------------------
;RANDOM EVENT: CHANCE OF FINDING A POTION
;-------------------------

    ;10% Chance to drop a potions
    BSR RAND100
    CMP.W   #10,D1
    BGE EVT2_DONE
    TST.B   POTION_CNT
    TST.B   POTION_CNT
    BEQ EVT2_DONE
    SUB.B   #1,POTION_CNT
EVT2_DONE:
    RTS    
        
;-------------------------
;DAMAGE EVENT: PUDDLE SLIP
;-------------------------
EVENT3:
    LEA EVENT3_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    MOVE.W  #5,D2
    BSR SCALE_DMG
    SUB.W   D2,HEALTH       ;PUDDLE SLIP DAMAGE
    RTS
  
;-------------------------
;PLAYER FEELS LUCKY + SMALL HEAL
;-------------------------  
EVENT4:
    LEA EVENT4_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    
    ADD.W   #5,HEALTH       ;SMALL HEAL FOR LUCKY DAY
    MOVE.B  (A3),D7
    ADD.B   #2,D7
    MOVE.B  D7,(A3)         ;LUCKY DAY ADDS+1 BRAVERY
    RTS    
COLLISION_HIT:
    LEA     HIT_MSG,A1      ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0

;-------------------------
;DAMAGE IS DEALT TO THE PLAYER
;-------------------------
    
    MOVE.W  #5,D2
    BSR SCALE_DMG
    SUB.W   D2,HEALTH       ;TRAP HURTS hurts a bit
    MOVE.B  (A3),D7
    SUB.B   #2,D7           ;SCARE=BRAVERY DOWN
    MOVE.B  D7,(A3)
    RTS                     ;RETURN FROM COLLISION_HIT: SUBROUTINE

;-------------------------
;NO DAMAGE ? CONFIDENCE UP
;-------------------------

COLLISION_MISS:
    LEA     MISS_MSG,A1		;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    
    MOVE.B  (A3),D7
    ADD.B   #1,D7           ;CONFIDENCE UP
    MOVE.B  D7,(A3)
    RTS                     ;RETURN FROM COLLISION_MISS: SUBROUTINE



*-------------------------------------------------------
*--------------------------LOOP-------------------------
*-------------------------------------------------------
LOOP:
    MOVE.B  #5, D3          ;LOOP COUNTER D3=5
NEXT:
    LEA     LOOP_MSG,A1     ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    SUB     #1,D3           ;DECREMENT LOOP COUNTER
    BNE     NEXT            ;REPEAT UNTIL D0=0
    RTS

*-------------------------------------------------------
*------------------SCREEN DECORATION--------------------
*-------------------------------------------------------
DECORATE:
    MOVE.B  #15, D3         ;LOOP COUNTER D3=60
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
OUT:
    LEA     LOOP_MSG,A1     ;ASSIGN MESSAGE TO ADDRESS REGISTER A1
    MOVE.B  #14,D0          ;MOVE LITERAL 14 TO DO
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    SUB     #1,D3           ;DECREMENT LOOP COUNTER
    BNE     OUT             ;REPEAT UNTIL D0=0
    BSR     ENDL            ;BRANCH TO ENDL SUBROUTINE
    RTS                     ;RETURN FROM DECORATE: SUBROUTINE

CLEAR_SCREEN:
    MOVE.B  #11,D0          ;CLEAR SCREEN
    MOVE.W  #$FF00,D1       ;SET COLOUR
    TRAP    #15             ;TRAP AND INTERPRET VALUE IN D0
    RTS                     ;RETURN FROM CLEAR_SCREEN: SUBROUTINE


*-------------------------------------------------------
*------------------------RANDOM + SCALING DAMAGE LOGIC SECTION-----------
*-------------------------------------------------------

; -------------------------------------------------------
; SCALE_DMG
; IN : D2 = base damage (word)
; OUT: D2 = scaled damage
; Rule: + (DAY / 2) and + (DIFFICULTY)
; -------------------------------------------------------
SCALE_DMG:
    MOVE.W  DAY,D7
    LSR.W   #1,D7          ; DAY/2 (day 1->0, day 3->1, day 5->2, day 7->3)
    ADD.W   D7,D2

    MOVE.B  DIFFICULTY,D7
    EXT.W   D7
    ADD.W   D7,D2

    RTS

;-------------------------------------------------------
; SUBROUTINE: RAND100
; Purpose   : Generate random number 0..99 in D1
; Inputs    : RNG_SEED (memory)
; Outputs   : D1 = 0..99, RNG_SEED updated
; Trashes   : D2
;-------------------------------------------------------

RAND100:
    ;seed =(seed *17+43) mod 65536
    MOVE.W  RNG_SEED,D2
    MULU    #17,D2
    ADD.W   #43,D2
    MOVE.W  D2,RNG_SEED

    ;take low byte and mod100
    ANDI.W  #$00FF,D2
    MOVE.W  D2,D1

MOD100_LOOP:
    CMP.W   #100,D1
    BLT     MOD100_DONE
    SUB.W   #100,D1
    BRA     MOD100_LOOP
MOD100_DONE:
    RTS

 

*-------------------------------------------------------
*------------------------END OF RANDOM + SCALING DAMAGE LOGIC SECTION-----------
*-------------------------------------------------------


*-------------------------------------------------------
*--------------START OF BOSS LOGIC SECTION-----------
*-------------------------------------------------------


;-------------------------
;STARTING INFO FOR BOSS: HEALTH, INTRO
;-------------------------
   
BOSS_DAY:
    BSR CLEAR_SCREEN
    BSR PRINT_FINAL_DAY_TITLE
    BSR PRESS_ANY_KEY

    BSR ENDL
    LEA BOSS_INTRO_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    MOVE.W  #100,LION_HP ;lion king hp

;-------------------------
;BOSS CORE
;-------------------------

BOSS_LOOP:
    BSR     BOSS_HUD         ;shows boss hp and player status
    BSR     BOSS_MENU        ;1/2/3
    BSR     CHECK_BOSS_END   ;if boss died

    ;if not attack
    BSR     BOSS_ATTACK

    ;if player lost battle
    BSR     CHECK_GAMEOVER

    BRA     BOSS_LOOP
;-------------------------
;SMALL HUD THAT SHOW BOSS STATUS FOR PLAYER DURING BATTLE
;-------------------------    
BOSS_HUD:
    BSR ENDL
    LEA BOSS_HP_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    MOVE.W LION_HP,D1
    MOVE.B #3,D0
    TRAP #15
    BSR ENDL

    ;show player status
    BSR HUD
    RTS 
;-------------------------
;HUD FOR BOSS OPTIONS DURING BATTLE: ATTACK-DEFEND-HEAL
;-------------------------
BOSS_MENU:
MENU_BOSS_SHOW:
    BSR ENDL
    LEA BOSS_MENU_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    LEA BOSS_OPT1_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    LEA BOSS_OPT2_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    LEA BOSS_OPT3_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    MOVE.B #4,D0
    TRAP #15      ;D1 = input

    CMP.B #1,D1
    BLT BOSS_BAD
    CMP.B #3,D1
    BGT BOSS_BAD

    CMP.B #1,D1
    BEQ BOSS_DO_ATTACK
    CMP.B #2,D1
    BEQ BOSS_DO_DEFEND
    BRA  BOSS_DO_POTION
;-------------------------
;BAD INPUT IS DEALT USING BOSS_BAD
;-------------------------
BOSS_BAD:
    LEA INVALID_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BRA MENU_BOSS_SHOW
;-------------------------
;BOSS MENSAGE:"INFLICTED(AMOUNT) OF DAMAGE"
;-------------------------
BOSS_DO_ATTACK:
    
    BSR ENDL
    LEA YOU_ATTACK_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    ;base damage 5-11
    BSR RAND100
    MOVE.W D1,D2
    
    MOVE.B  (A3),D7 ; A3=LOCATION OF BASE BRAVERY=AFFECTS BRAVERY
    LSR.B   #2,D7
    EXT.W   D7
    ADD.W   D7,D2
    
D_MOD7:
    CMP.W #7,D2
    BLT D_OK7
    SUB.W #7,D2
    BRA D_MOD7
D_OK7:
    ADD.W #6,D2      ;D2 = 6..12

;-------------------------
;SPECIAL CONDITION FOR BATTLE IF GROWLER
;-------------------------
    MOVE.B CHAR_CHOICE,D3
    CMP.B #1,D3
    BNE NO_GROWLER_BONUS
    ADD.W #3,D2
    
;-------------------------
;IF PLAYER IS USING STRAY INSTEAD
;-------------------------    
NO_GROWLER_BONUS:

    ;damage to the boss
   MOVE.W  D2,LAST_PLAYER_DMG   ; 

    ;damage to the boss
    MOVE.W   LAST_PLAYER_DMG,D2   ; 
    SUB.W    D2,LION_HP

    BSR ENDL
    LEA DMG_TO_BOSS_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    MOVE.W  LAST_PLAYER_DMG,D1       ; 
    MOVE.B  #3,D0
    TRAP    #15
    RTS


;-------------------------
;REDUCE DAMAGE IF DEFEND IS SELECTED
;-------------------------
BOSS_DO_DEFEND:
    BSR ENDL
    LEA YOU_DEFEND_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    MOVE.B #1,DEFEND_FLAG     ;boss attack will hit less

    ;courage +1 per points of bravery
    MOVE.B (A3),D7
    ADD.B #1,D7
    MOVE.B D7,(A3)
    RTS

;-------------------------
;IF PLAYER HAS POTION AVAILABLE DO:
;-------------------------  
BOSS_DO_POTION:
    BSR ENDL
    LEA YOU_POTION_MSG,A1
    MOVE.B #14,D0
    TRAP #15

    TST.B POTION_CNT
    BEQ NO_POTION_BOSS

    SUB.B #1,POTION_CNT

    ;reduce weight after using potion
    TST.B CURRENT_WEIGHT
    BEQ SKIP_WEIGHT_DEC
    SUB.B #1,CURRENT_WEIGHT
SKIP_WEIGHT_DEC:

    ADD.W #15,HEALTH

    BSR ENDL
    LEA POTION_OK_BOSS_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS

NO_POTION_BOSS:
    BSR ENDL
    LEA POTION_FAIL_BOSS_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    RTS    
;-------------------------
;BOSS DAMAGE
;-------------------------
BOSS_ATTACK:
    MOVE.W  LION_HP,D0
    BLE     BOSS_ATK_END

    BSR     ENDL
    LEA     BOSS_ATTACK_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15

    ; base damage 6..12 into D2
    BSR     RAND100
    MOVE.W  D1,D2
D_MOD7B:
    CMP.W   #7,D2
    BLT     D_OK7B
    SUB.W   #7,D2
    BRA     D_MOD7B
D_OK7B:
    ADD.W   #7,D2

    ; defend reduces damage
    TST.B   DEFEND_FLAG
    BEQ     NO_DEF_REDUCE
    LSR.W   #1,D2
    CLR.B   DEFEND_FLAG
NO_DEF_REDUCE:

    ; scale with day/difficulty
  ;  BSR     SCALE_DMG
;-------------------------
;ENRAGE: SPECIAL BOSS ABILITY WHEN LOW IN HEALTH
;-------------------------
    MOVE.W  LION_HP,D0
    CMP.W   #35,D0
    BGE     ENRAGE_DONE
    ADD.W   #3,D2
ENRAGE_DONE:

;-------------------------
;BOSS CAN HIT CRITICAL HITS OF 6% MORE DAMAGE THAN NORMAL
;-------------------------
    MOVE.W  D2,D5
    BSR     RAND100
    MOVE.W  D5,D2

    CMP.W   #6,D1
    BGE     NO_CRIT
    ADD.W   D2,D2         

    ; print crit 
    MOVEM.L D2,-(A7)
    BSR     ENDL
    LEA     CRIT_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    MOVEM.L (A7)+,D2
NO_CRIT:

    ; apply damage ONCE
    SUB.W   D2,HEALTH

    ; print damage (TRAP safe)
    MOVEM.L D2,-(A7)
    BSR     ENDL
    LEA     DMG_TO_YOU_MSG,A1
    MOVE.B  #14,D0
    TRAP    #15
    MOVEM.L (A7)+,D2

    MOVE.W  D2,D1
    MOVE.B  #3,D0
    TRAP    #15

BOSS_ATK_END:
    RTS


;-------------------------
;CHECKS IF BOSS LOST
;-------------------------    
CHECK_BOSS_END:
    MOVE.W LION_HP,D0
    BGT NOT_DONE_BOSS

    BSR ENDL
    LEA BOSS_DEFEATED_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL

    MOVE.B CHAR_CHOICE,D1
    CMP.B #1,D1
    BEQ WIN_GROWLER_END
    BRA WIN_STRAY_END
;-------------------------
;BRANCHES FOR VICTORY FOR STRAY AND GROWLER
;-------------------------
WIN_GROWLER_END:
    LEA END_GROWLER_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BRA GAME_END

WIN_STRAY_END:
    LEA END_STRAY_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BRA GAME_END

NOT_DONE_BOSS:
    RTS

;-------------------------
;INSPECT TO SHOW PLAYER STATUS
;-------------------------
DO_INSPECT:
    BSR HUD
    BRA MENU_SHOW    
;-------------------------
;INVALID KEY SELECTED DO:
;-------------------------
MENU_BAD:
    BSR ENDL
    LEA INVALID_MSG,A1
    MOVE.B #14,D0
    TRAP #15
    BRA MENU_SHOW    


*-------------------------------------------------------
*------------------STORY PER DAY (BRANCH)---------------
*-------------------------------------------------------

STORY_BEAT:
    ;DECIDE WHICH STORY SET (GROWLER=1, STRAY=2)

    BSR PRINT_DAY_TITLE

    MOVE.B  CHAR_CHOICE,D0
    CMP.B   #1,D0
    BEQ     STORY_GROWLER
    BRA     STORY_STRAY

;-------------------------
;TITLE FOR FINAL DAY:
;-------------------------
PRINT_FINAL_DAY_TITLE:
    BSR ENDL
    BSR PRINT_LINE
    LEA FINALDAY_TITLE,A1
    MOVE.B #14,D0
    TRAP #15
    BSR ENDL
    BSR PRINT_LINE
    RTS
;-------------------------
;BRANCH FOR GROWLER
;-------------------------
STORY_GROWLER:
    MOVE.W  DAY,D1
    CMP.W   #1,D1
    BEQ     GDAY1
    CMP.W   #2,D1
    BEQ     GDAY2
    CMP.W   #3,D1
    BEQ     GDAY3
    CMP.W   #4,D1
    BEQ     GDAY4
    CMP.W   #5,D1
    BEQ     GDAY5
    CMP.W   #6,D1
    BEQ     GDAY6
    CMP.W   #7,D1
    BEQ     GDAY7
    BRA     STORY_DONE

GDAY1:  LEA GROWLER_D1,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

GDAY2:  LEA GROWLER_D2,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

GDAY3:  LEA GROWLER_D3,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

GDAY4:  LEA GROWLER_D4,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

GDAY5:  LEA GROWLER_D5,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

GDAY6:  LEA GROWLER_D6,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

GDAY7:  LEA GROWLER_D7,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

;-------------------------
;BRANCH FOR STRAY
;-------------------------
STORY_STRAY:
    MOVE.W  DAY,D1
    CMP.W   #1,D1
    BEQ     SDAY1
    CMP.W   #2,D1
    BEQ     SDAY2
    CMP.W   #3,D1
    BEQ     SDAY3
    CMP.W   #4,D1
    BEQ     SDAY4
    CMP.W   #5,D1
    BEQ     SDAY5
    CMP.W   #6,D1
    BEQ     SDAY6
    CMP.W   #7,D1
    BEQ     SDAY7
    BRA     STORY_DONE

SDAY1:  LEA STRAY_D1,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

SDAY2:  LEA STRAY_D2,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

SDAY3:  LEA STRAY_D3,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

SDAY4:  LEA STRAY_D4,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

SDAY5:  LEA STRAY_D5,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

SDAY6:  LEA STRAY_D6,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

SDAY7:  LEA STRAY_D7,A1
        MOVE.B #14,D0
        TRAP #15
        BRA STORY_AFTER

STORY_AFTER:
    BSR ENDL
    BSR PRESS_ANY_KEY
    RTS

STORY_DONE:
    RTS                   
*-------------------------------------------------------
*-------------------DATA DECLARATIONS--------------------
*-------------------------------------------------------

; ---------------- PROMPTS/MSGs DATA ----------------
CRLF:                  DC.B    $0D,$0A,0
WELCOME_MSG:           DC.B    '************************************************************'
                       DC.B    $0D,$0A
                       DC.B    'WELCOME TO THE KINGDOM OF HEARTS!',$0D,$0A 
                       DC.B    'THE LAND IS CURRENTLY BEING RULED BY THE TERRIBLE LION KING',$0D,$0A
                       DC.B    'YOU WERE CHOSEN TO FREE THIS LAND FROM HIS CONTROL!!! ',0
                       DC.B    $0D,$0A 
                       DC.B    'NOW, CHOOSE YOUR ADVENTURER',$0D,$0A 
                       DC.B    'CHOOSE WISELY AS YOU WONT BE ABLE TO CHANGE IT TILL THE END OF THE GAME:',$0D,$0A
                       DC.B    $0D,$0A
                       DC.B    '1. THE GROWLER, THE STRONGEST DOG WARRIOR FROM OUR KINGDOM',$0D,$0A 
                       DC.B    'HIS ENTIRE FAMILY WAS KILLED BY THE LION KING, HES NOW LOOKING FOR VENGEANCE AGAINST THE LION KING',$0D,$0A
                       DC.B    'GROWLER HAS A STARTING BONUS OF BRAVERY AND STRENGHT AND CAN CARRY MORE WEIGHT IN ITS INVENTORY',0
                       DC.B    $0D,$0A
                       DC.B    '2. STRAY, THE FASTEST CAT OF THE KINGDOM',$0D,$0A 
                       DC.B    'A MERCENARY LONE CAT LITTLE IS KNOW ABOUT HIS ORIGINS',$0D,$0A 
                       DC.B    'HE FOLLOWS GOLD WHEREVER HE CAN FIND IT',0
                       DC.B    'STRAY HAS A STARTING BONUS OF SPEED BUT CAN CARRY LESS WEIGHT'
                       DC.B    $0D,$0A
PRESSKEY_MSG:          DC.B 'PRESS ANY KEY TO CONTINUE...',0                

CHAR_PROMPT:           DC.B    'ENTER 1 FOR GROWLER OR 2 FOR STRAY:',0
DOG_MSG:               DC.B    'YOU CHOSE GROWLER(Soldier)',0
CAT_MSG:               DC.B    'YOU CHOSE STRAY(Mercenary)',0          
DAY_STORY_MSG:         DC.B 'DAY ',0

EXPLORE_MSG:           DC.B 'YOU MOVE QUIETLY THROUGH THE WILDERNESS...',0
LOOT_MSG:              DC.B 'YOU SEARCH THE GROUND...',0
GAIN_POTION_MSG:       DC.B 'YOU FOUND A SMALL POTION (+1)!',0
NO_SPACE_MSG:          DC.B 'YOUR INVENTORY IS TOO HEAVY. YOU LEAVE IT BEHIND.',0

HURT_MSG:              DC.B 'DANGER! SOMETHING ATTACKS YOU!',0
HURT_RESULT_MSG:       DC.B 'YOU LOSE -5 HEALTH AND -2 BRAVERY.',0

NOTHING_MSG:           DC.B 'NOTHING HAPPENS... BUT YOU FEEL MORE CONFIDENT.',0
NOTHING_RESULT_MSG:    DC.B 'BRAVERY +1',0

REST_MSG:              DC.B 'YOU REST FOR A WHILE...',0
REST_OK_MSG:           DC.B 'YOU FEEL BETTER. HEALTH +8',0
REST_DOWN_MSG:         DC.B 'REST MAKES YOU DOUBT YOURSELF. BRAVERY -1',0

PREPARE_MSG:           DC.B 'YOU PREPARE YOUR GEAR AND FOCUS...',0
PREP_OK_MSG:           DC.B 'TRAINING SUCCESS! POTION -1, BRAVERY +3',0
PREP_FAIL_MSG:         DC.B 'NO POTIONS LEFT. YOU FEEL UNPREPARED. BRAVERY -1',0

PROMPT_MISS:           DC.B    'ENTER 1-3: ',0
SUCCESS_MSG:           DC.B    'SUCCESS! BRAVERY +',0
FAIL_MSG:              DC.B    'FAILED! BRAVERY -',0
DAMAGE_MSG:            DC.B    'YOU TOOK DAMAGE: ',0
GAMEOVER_MSG:          DC.B    'GAME OVER!',0
DAY_MSG:               DC.B    'DAY:',0
HEALTH_MSG:            DC.B    'HEALTH: ',0
POT_MSG:               DC.B    'POTIONS:',0
WEP_MSG:               DC.B    'WEAPON:',0
SEP_LINE:              DC.B '------------------------------------------------------------',0
DAY_TITLE_A:           DC.B '=== DAY ',0
DAY_TITLE_B:           DC.B ' ===',0

CRIT_MSG:              DC.B    'CRITICAL HIT!',0
DIFF_MSG               DC.B    'DIFFICULTY LEVEL: ',0
ACTION_MSG:            DC.B    '1)INSPECT 2)CONTINUE TO MISSION',0
INSPECT_TITLE          DC.B    '--- INSPECT ---',0
LEGEND_MSG:            DC.B    'A MYSTERIOUS WANDERER HEALS YOUR WOUNDS. YOU FEEL POWERFUL',0
DESC1_MSG:             DC.B    'THE WIND HOWLS THROUGJ THE TREES. SOMETHING WATHCHES YOU.',0
DESC2_MSG:             DC.B   'THE SKY IS DARK AND THE LAND FEELS UNEASY.',0
GAMEPLAY_MSG:          DC.B    'YOUR ADVENTURE BEGINS!',0
UPDATE_MSG:            DC.B    'UPDATING QUEST STATUS...',0
DRAW_MSG:              DC.B    'REDRAWING WORLD...',0
HIT_MSG:               DC.B    'OH NO! YOU FELL INTO A TRAP!',0
MISS_MSG:              DC.B    'OH NO, SOMEONE SHOT A ARROW AT YOU. SAFE! IT HIT A TREE.',0
EVENT2_MSG:            DC.B    'SUDDEN WIND BLAST! LOST YOUR BALANCE.',0
EVENT3_MSG:            DC.B    'SLIPPED ON A PUDDLE! OUCH. -5 HEALTH',0
EVENT4_MSG:            DC.B    'SAFE DAY! YOU FEEL LUCKY.',0
LOOP_MSG:              DC.B    '.',0
REPLAY_MSG:            DC.B    'ENTER 0 TO QUIT, ANY OTHER NUMBER TO REPLAY: ',0
CONTINUE_MSG:          DC.B    'PRESS ANYKEY TO CONTINUE: ',0
HUD_MSG:               DC.B    'BRAVERY POINTS: ',0

; ---------------- ITEMS DATA ----------------
   
                       DC.B    '************************************************************'
                       DC.B    $0D,$0A,0
POTIONS_MSG:           DC.B    'COLLECT SMALL POTIONS, JUST IN CASE YOU NEED THEM! ENTER QUANTITY: ',0
INVALID_MSG:           DC.B    'INVALID INPUT - TRY AGAIN.',0
POTION_OK_MSG:         DC.B    'POTIONS SET TO: ',0
WEAPON_OK_MSG:         DC.B    'WEAPON CHOICE SET TO',0
WEAPONS_LIST:          DC.B    'EQUIP WEAPONS: 1=BONE SWORD, 2=WOLVERINE CLAWS , 3=BOW',0
; ---------------- MISSIONS DATA ----------------
MISSION_MSG:           DC.B    'CHOOSE A MISSION:', 0
DAY_MENU_MSG:          DC.B 'CHOOSE YOUR ACTION:',$0D,$0A,0
OPT1_MSG:              DC.B '1) EXPLORE THE AREA (RISK / REWARD)',$0D,$0A,0
OPT2_MSG:              DC.B '2) REST (RECOVER HEALTH)',$0D,$0A,0
OPT3_MSG:              DC.B '3) PREPARE (POTION -> TRAIN)',$0D,$0A,0
OPT0_MSG:              DC.B '0) INSPECT (SHOW STATUS)',$0D,$0A,0



; ---------------- STORY TEXTS ----------------
GROWLER_D1:            DC.B   'Growler wakes up. His house is raided by the Lion Kings hyenas.',$0D,$0A 
                       DC.B   'He barely escapes, growler: "It''s time to end his kingdom."',0
GROWLER_D2:            DC.B   'A survivor speaks of a hidden tunnel to the castle.',$0D,$0A 
                       DC.B   'Supplies are scarce... but revenge keeps you moving.',0
GROWLER_D3:            DC.B   'A patrol attacks. You fight through.',$0D,$0A 
                       DC.B   'The Lion King now knows your name.',0
GROWLER_D4:            DC.B   'An old lady offers a torn map piece if you help her.',$0D,$0A 
                       DC.B       'The path to the castle becomes clearer.',0
GROWLER_D5:            DC.B   'The swamp bites back.',$0D,$0A 
                       DC.B       'You suffer, but find a small talisman of courage in the mud.',0
GROWLER_D6:            DC.B   'You reach the castle gates.',$0D,$0A 
                       DC.B       'The air is heavy. Tomorrow, the Lion King falls.',0
GROWLER_D7:            DC.B   'Inside the castle... the Lion King waits. This ends now.',0

STRAY_D1:              DC.B        'Sunny day. Stray hates the sun and hides in alley shadows.',$0D,$0A 
                       DC.B        'A contractor offers 10,000 gold for the Lion King''s head.',$0D,$0A 
                       DC.B        'Risky... but freedom has a price. Stray:"Il''take it"',0
STRAY_D2:              DC.B     'Rumors lead you to the black market.',$0D,$0A 
                       DC.B     'Information costs gold... or favors.',0
STRAY_D3:              DC.B     'You steal a guard insignia and slip past a patrol.',$0D,$0A 
                       DC.B     'No hero moves this quietly.',0
STRAY_D4:              DC.B     'A wounded hunter knows the castle routes.',$0D,$0A 
                       DC.B         'You help him... and surprise yourself.',$0D,$0A
STRAY_D5:              DC.B     'The tunnel is filled with ancient traps.',$0D,$0A
                       DC.B     'Your claws and reflexes save you again and again.',0
STRAY_D6:              DC.B     'From a rooftop, you see the Lion King''s rule crushing the land.',$0D,$0A 
                       DC.B         'Maybe this job is more than gold.',0
STRAY_D7:              DC.B     'The throne room. The Lion King stands tall.',$0D,$0A 
                       DC.B     'Time to collect the bounty... and end the terror.',0
FINALDAY_TITLE:        DC.B '=== FINAL DAY ===',0
; ---------------- BOSS / ENDINGS ----------------
BOSS_WIN_MSG:          DC.B 'VICTORY! The Lion King falls. The kingdom is free!',0
;BOSS_LOSE_MSG:         DC.B 'DEFEAT! The Lion King overwhelms you. (-30 HP) You barely escape...but your are finally at peace',0

END_GROWLER_LOSE_MSG:  DC.B 'ENDING: You were not capable of avenging your family, but at least you can rest in peace with them.',$0D,$0A 
                       DC.B 'The Lion King''s reign ends in justice and fury.',0
END_STRAY_LOSE_MSG:    DC.B 'ENDING: He''s too strong...',$0D,$0A 
                       DC.B 'You bleed in the floor...memories of a better life pass across your eyes',$0D,$0A
                       DC.B 'as you die.',0

BOSS_INTRO_MSG:        DC.B 'THE CASTLE GATES OPEN... THE LION KING STANDS BEFORE YOU!',0
BOSS_HP_MSG:           DC.B 'LION KING HP: ',0

BOSS_MENU_MSG:         DC.B 'FINAL BATTLE - CHOOSE:',0
BOSS_OPT1_MSG:         DC.B '1) ATTACK',0
BOSS_OPT2_MSG:         DC.B '2) DEFEND',0
BOSS_OPT3_MSG:         DC.B '3) USE POTION (+15 HEALTH)',0

YOU_ATTACK_MSG:        DC.B 'YOU STRIKE THE LION KING!',0
YOU_DEFEND_MSG:        DC.B 'YOU BRACE FOR IMPACT!',0
YOU_POTION_MSG:        DC.B 'YOU REACH FOR A POTION...',0

POTION_OK_BOSS_MSG:    DC.B 'HEAL +15! YOU FEEL STRONGER.',0
POTION_FAIL_BOSS_MSG:  DC.B 'NO POTIONS LEFT!',0

DMG_TO_BOSS_MSG:       DC.B 'DAMAGE TO LION KING: ',0
BOSS_ATTACK_MSG:       DC.B 'THE LION KING ATTACKS!',0
DMG_TO_YOU_MSG:        DC.B 'DAMAGE TO YOU: ',0

BOSS_DEFEATED_MSG:     DC.B 'THE LION KING FALLS. THE KINGDOM IS FREE!',0
END_GROWLER_MSG:       DC.B 'GROWLER AVENGES HIS FAMILY. HE BECOMES THE GUARDIAN OF THE KINGDOM.',0
END_STRAY_MSG:         DC.B 'STRAY CLAIMS THE REWARD... BUT CHOOSES TO STAY AND HELP REBUILD IN SECRET.',0

; ---------------- DS DATA ----------------
LAST_EVENT:            DS.B    1   ;Stores event ID, most recent  
CHAR_CHOICE:           DS.B    1   ;1=GROWLER, 2=STRAY
LION_HP:               DS.W    1
DEFEND_FLAG:           DS.B    1
MAX_WEIGHT:            DS.B    1
CURRENT_WEIGHT:        DS.B    1
HEALTH:                DS.W    1   ;PLAYERS HEALTH
POTION_CNT:            DS.B    1   ;1..9
WEAPON_CHOICE:         DS.B    1   ;1..3
DAY:                   DS.W    1   ;day counter
DIFFICULTY:            DS.B    1   ;scales over time
RNG_SEED:              DS.W    1   ;simple RNG seed
SCORE:                 DS.W    1   ;RESERVE SPACE FOR SCORE
LAST_BOSS_DMG:         DS.W    1
LAST_PLAYER_DMG:       DS.W    1

    END START

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
```










*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
