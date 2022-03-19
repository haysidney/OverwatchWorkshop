settings {
    "main": {
        "modeName": "Lil Buddies"
    },
    "lobby": {
        "mapRotation": "paused",
        "spectatorSlots": 12,
        "returnToLobby": "never"
    },
    "gamemodes": {
        "ffa": {
            "enabledMaps": [
                "workshopIsland"
            ],
            "gameLengthInMn": 15,
            "scoreToWin": 5000,
            "enableSelfInitiatedRespawn": false
        },
        "elimination": {
            "enabled": false,
            "heroesAvailable": "random",
            "scoreToWin": 9
        },
        "general": {
            "enableHeroSwitching": false,
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "respawnTime%": 0
        }
    },
    "heroes": {
        "allTeams": {
            "genji": {
                "enablePrimaryFire": false,
                "enableMelee": false,
                "enableSecondaryFire": false,
                "enableUlt": false
            },
            "zenyatta": {
                "enableInfiniteAmmo": true,
                "enableAbility2": false,
                "enableAbility1": false,
                "enableMelee": false,
                "enableUlt": false
            },
            "enabledHeroes": [
                "genji",
                "zenyatta"
            ]
        }
    },
    "workshop": {
        "Bot Count": 1,
        "Pets": true
    }
}

#Global variables

globalvar AICount 0


#Player variables

playervar _SlotNumberTextID 0
playervar _Wandering 1
playervar _WanderDestination 2
playervar _PlayerType 3
playervar _ParentPlayer 4
playervar _PlayersTargetingMe 5
playervar _LastPlayerHit 6
playervar _PetState 7
playervar _OrbsOnMe 8


#Subroutine names

subroutine SpawnBots 0
subroutine SpawnPet 1


#Activated extensions

#!extension spawnMoreDummyBots


rule "Init":
    @Condition getTotalTimeElapsed() > 2
    
    AICount = createWorkshopSetting(int[0:2], "Bots", "Bot Count", 0, 0)
    getAllPlayers().disableGamemodeHud()
    #getAllPlayers().disableHeroHUD()
    getAllPlayers().enableMessages()
    disableAnnouncer()
    disableGamemodeCompletion()
    disableMusic()
    disableScoring()
    SpawnBots()
    startGamemode()


rule "Humans - Init":
    @Event playerJoined
    @Condition eventPlayer.isDummy() == false
    
    eventPlayer._PlayerType = "Human"


rule "Bots/Humans - Init":
    @Event eachPlayer
    @Condition (eventPlayer._PlayerType == "Human" or eventPlayer._PlayerType == "Bot") == true
    
    eventPlayer.startForcingHero(Hero.ZENYATTA)
    hudText(eventPlayer, "Info", "Debug", "Slot: {0}".format(eventPlayer.getSlot()), HudPosition.LEFT, 0, Color.WHITE, Color.WHITE, Color.WHITE, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.DEFAULT)
    #Human/Pet Friendly Fire
    startDamageModification([player for player in getAllPlayers() if player._ParentPlayer == eventPlayer], eventPlayer, 0, DamageReeval.RECEIVERS_AND_DAMAGERS)
    eventPlayer._PlayersTargetingMe = []
    eventPlayer._OrbsOnMe = []


rule "Humans - SpawnPet":
    @Event eachPlayer
    @Condition eventPlayer._PlayerType == "Human"
    @Condition eventPlayer.isHoldingButton(Button.INTERACT) == true
    
    SpawnPet()


rule "Damage Orb Attacker":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(Button.ABILITY_1) == true
    
    smallMessage(eventPlayer, "Discord Orb")
    eventPlayer._LastPlayerHit = raycast(eventPlayer.getEyePosition(), eventPlayer.getEyePosition() + eventPlayer.getFacingDirection() * 100, [player for player in getAllPlayers() if player._ParentPlayer != eventPlayer], eventPlayer, false).getPlayerHit()
    if eventPlayer._LastPlayerHit == null:
        ([player for player in getAllPlayers() if eventPlayer in player._PlayersTargetingMe])._PlayersTargetingMe.remove(eventPlayer)
    else:
        if not eventPlayer in eventPlayer._LastPlayerHit._PlayersTargetingMe:
            eventPlayer._LastPlayerHit._PlayersTargetingMe.append(eventPlayer)


rule "Damage Orb Victim":
    @Event eachPlayer
    
    if len(eventPlayer._PlayersTargetingMe) > 0 and len(eventPlayer._OrbsOnMe) == 0:
        createEffect(getAllPlayers(), Effect.ORB, Color.PURPLE, eventPlayer, 1, EffectReeval.VISIBILITY_POSITION_AND_RADIUS)
        eventPlayer._OrbsOnMe.append(getLastCreatedEntity())
    elif len(eventPlayer._PlayersTargetingMe) == 0 and len(eventPlayer._OrbsOnMe) > 0:
        destroyEffect(eventPlayer._OrbsOnMe)
        eventPlayer._OrbsOnMe = []
    wait(0.25)
    goto RULE_START


rule "Bots - Init":
    @Event eachPlayer
    @Condition eventPlayer._PlayerType == "Bot"
    
    if eventPlayer._SlotNumberTextID == 0:
        createInWorldText(getAllPlayers(), eventPlayer.getSlot(), eventPlayer, 1, Clip.SURFACES, WorldTextReeval.VISIBILITY_POSITION_AND_STRING, Color.WHITE, SpecVisibility.DEFAULT)
        eventPlayer._SlotNumberTextID = getLastCreatedText()


rule "Bots - Wandering":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == true
    @Condition createWorkshopSetting(bool, "Bots", "Wandering", false, 0) == true
    
    if eventPlayer._Wandering:
        eventPlayer.setFacing(vectorTowards(eventPlayer.getPosition(), eventPlayer._WanderDestination), Relativity.TO_WORLD)
        if distance(eventPlayer.getPosition(), eventPlayer._WanderDestination) <= 4:
            eventPlayer.stopThrottleInDirection()
            eventPlayer._Wandering = false
        else:
            eventPlayer.startThrottleInDirection(eventPlayer.getFacingDirection(), 0.9, Relativity.TO_WORLD, Throttle.REPLACE_EXISTING, ThrottleReeval.DIRECTION_AND_MAGNITUDE)
    else:
        #TODO Find a random walkable position within a range of the player.
        eventPlayer._WanderDestination = getClosestPlayer(hostPlayer.getPosition(), Team.ALL).getPosition()
        eventPlayer._Wandering = true
    wait(0.1)
    goto RULE_START


rule "Pets - Init":
    @Event eachPlayer
    @Condition eventPlayer._PlayerType == "Pet"
    
    #createInWorldText(getAllPlayers(), "Team: {1} Slot: {0}".format(eventPlayer.getSlot(), eventPlayer.getTeam()), eventPlayer, 1, Clip.SURFACES, WorldTextReeval.VISIBILITY_POSITION_AND_STRING, Color.WHITE, SpecVisibility.DEFAULT)
    eventPlayer.startForcingName("{0}".format(eventPlayer.getSlot()))
    eventPlayer.startForcingOutlineFor(eventPlayer._ParentPlayer, true, Color.WHITE, OutlineVisibility.DEFAULT)


rule "Pets - Follow":
    @Event eachPlayer
    @Condition eventPlayer._PlayerType == "Pet"
    @Condition eventPlayer._PetState == "Follow"
    
    #if not RULE_CONDITION:
    #        return
    eventPlayer.setFacing(directionTowards(eventPlayer.getPosition(), eventPlayer._ParentPlayer.getPosition()), Relativity.TO_WORLD)
    if distance(eventPlayer.getPosition(), eventPlayer._ParentPlayer) <= 4:
        eventPlayer.stopThrottleInDirection()
    else:
        eventPlayer.startThrottleInDirection(eventPlayer.getFacingDirection(), 0.9, Relativity.TO_WORLD, Throttle.REPLACE_EXISTING, ThrottleReeval.DIRECTION_AND_MAGNITUDE)
    wait(0.1, Wait.ABORT_WHEN_FALSE)
    goto RULE_START


rule "Pets - Attack":
    @Event eachPlayer
    @Condition eventPlayer._PlayerType == "Pet"
    @Condition eventPlayer._PetState == "Attack"
    
    #if not RULE_CONDITION:
    #        return
    eventPlayer.setFacing(directionTowards(eventPlayer.getPosition(), (([player for player in getAllPlayers() if eventPlayer._ParentPlayer in player._PlayersTargetingMe])[0]).getPosition()), Relativity.TO_WORLD)
    if distance(eventPlayer.getPosition(), (([player for player in getAllPlayers() if eventPlayer._ParentPlayer in player._PlayersTargetingMe])[0]).getPosition()) <= 4:
        eventPlayer.stopThrottleInDirection()
    else:
        eventPlayer.startThrottleInDirection(eventPlayer.getFacingDirection(), 0.9, Relativity.TO_WORLD, Throttle.REPLACE_EXISTING, ThrottleReeval.DIRECTION_AND_MAGNITUDE)
    wait(0.1, Wait.ABORT_WHEN_FALSE)
    goto RULE_START


rule "Pets - Status":
    @Event eachPlayer
    @Condition eventPlayer._PlayerType == "Pet"
    
    #Check if we're targetting someone
    if len([player for player in getAllPlayers() if eventPlayer._ParentPlayer in player._PlayersTargetingMe]) > 0:
        if eventPlayer._PetState != "Attack":
            #eventPlayer.stopThrottleInDirection()
            eventPlayer._PetState = "Attack"
    else:
        if eventPlayer._PetState != "Follow":
            #eventPlayer.stopThrottleInDirection()
            eventPlayer._PetState = "Follow"
    wait(0.1)
    goto RULE_START


def SpawnBots():
    @Name "SpawnBots()"
    
    if AICount == (len([player for player in getAllPlayers() if player._PlayerType == "Bot"])):
        return
    if AICount < (len([player for player in getAllPlayers() if player._PlayerType == "Bot"])):
        destroyDummy(Team.ALL, (([player for player in getAllPlayers() if player._PlayerType == "Bot"]).last()).getSlot())
    else:
        createDummy(Hero.GENJI, Team.ALL, getNumberOfPlayers(Team.ALL), random.choice(getSpawnPoints(Team.ALL)), vect(0, 0, 0))
        #PlayerTypes: Human, Bot, Pet
        getLastCreatedEntity()._PlayerType = "Bot"
    goto RULE_START


def SpawnPet():
    @Name "SpawnPet()"
    
    if not createWorkshopSetting(bool, "Bots", "Pets", false, 0):
        return
    createDummy(Hero.GENJI, Team.ALL, -1, nearestWalkablePosition(eventPlayer.getPosition()), directionTowards(nearestWalkablePosition(eventPlayer.getPosition()), eventPlayer.getPosition()))
    getLastCreatedEntity()._PlayerType = "Pet"
    getLastCreatedEntity()._ParentPlayer = eventPlayer
    eventPlayer._PetState = "Follow"


rule "Skip Assembling Heros":
    @Condition isAssemblingHeroes() == true
    
    setMatchTime(0)


