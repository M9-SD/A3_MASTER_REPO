
comment "
/*
    =======================================================================================
    SCRIPT: Suicide Vest AI
    AUTHOR: M9-SD
    DESCRIPTION: 
        - Spawns an AI unit that tracks and hunts players, then detonates near them.
        - Highly optimized and configurable via missionNamespace variables.
    =======================================================================================
*/
";

comment "Initialize reference to the new unit";
private _bombVestAI = this;

comment "Congfigure settings";
M9_bombVestAI_team = resistance; comment "Options: resistance, independent, east, west, etc.";
M9_bombVestAI_targetRadius = 1000; comment "Metric: meters";
M9_bombVestAI_targetRestrictions = [civilian, M9_bombVestAI_team]; comment "(friends)";
M9_fnc_bombVestAI_getTargets = {
	params [['_bombVestAI', objNull]]; 
	private _potentialTargets = [];
	{
		if (isNull _x) then {continue};
		if (!alive _x) then {continue};
		if (_x == _bombVestAI) then {continue};
		if (typeOf _x == 'ModuleExplosive_DemoCharge_F') then {continue};
		if (side (group _x) in M9_bombVestAI_targetRestrictions) then {continue};
		_potentialTargets pushBackUnique _x
	} forEach ( (vehicles + allUnits + allPlayers) - [_bombVestAI] ); comment "Options: allUnits, allPlayers, vehicles, etc";
	_potentialTargets;
}; 
M9_bombVestAI_targetTypes = [_bombVestAI] call M9_fnc_bombVestAI_getTargets;

comment "Init settings on all clients";
"
publicVariable 'M9_bombVestAI_targetRadius';
publicVariable 'M9_bombVestAI_targetTypes';
";

comment "Set animation speed coefficient to 1.5x for enhanced motion fluidity";
_bombVestAI setAnimSpeedCoef 1.5;

comment "Temporarily make the unit invulnerable on spawn";
_bombVestAI spawn {
    _this allowDamage false;
    sleep 1;
    _this allowDamage true;
};

comment "Stop any current AI pathfinding or animation";
doStop _bombVestAI;

comment "Minimize unit's camouflage and audibility for stealth";
_bombVestAI setUnitTrait ["camouflageCoef", 0];
_bombVestAI setUnitTrait ["audibleCoef", 0];

comment "Disable stamina to prevent exhaustion mechanics";
_bombVestAI enableStamina false;

comment "Make AI join specified team";
while {M9_bombVestAI_team != side (group _bombVestAI)} do {
	[_bombVestAI] joinSilent (createGroup [M9_bombVestAI_team, true]);
	sleep 0.01;
};

comment "Disable all AI behaviors, then selectively enable required features";
_bombVestAI disableAI "ALL";
_bombVestAI enableAI "TEAMSWITCH";
_bombVestAI enableAI "ANIM";
_bombVestAI enableAI "MOVE";
_bombVestAI enableAI "PATH";

comment "Set AI to careless behavior and maximum movement speed";
_bombVestAI setBehaviour "CARELESS";
_bombVestAI setSpeedMode "FULL";

comment "Set overall AI skills and traits to maximum";
_bombVestAI setSkill 1;
_bombVestAI setSkill ["spotDistance", 1];
_bombVestAI setSkill ["spotTime", 1];
_bombVestAI setSkill ["courage", 1];
_bombVestAI setSkill ["commanding", 1];

comment "Prevent the unit from fleeing under any circumstances";
_bombVestAI allowFleeing 0;

comment "Force constant movement speed at 6 m/s";
_bombVestAI forceSpeed 6;

comment "Force unit to stand upright (no crouch or prone)";
_bombVestAI setUnitPos "UP";

comment "Spawn loop to continuously reveal and track the nearest player";
[_bombVestAI] spawn {
    params ["_bombVestAI"];

    comment "Disable stamina and fatigue";
    _bombVestAI enableStamina false;
    _bombVestAI enableFatigue false;

    comment "Mutually reveal all players and their vehicles to the new unit";
    {
        [_bombVestAI, _x] remoteExec ["reveal"];
        [_x, _bombVestAI] remoteExec ["reveal"];
        [_bombVestAI, vehicle _x] remoteExec ["reveal"];
        [vehicle _x, _bombVestAI] remoteExec ["reveal"];
    } forEach allPlayers;

    comment "Main loop: move toward the nearest player every 8 seconds";
    while {alive _bombVestAI} do {
		private _vAI = vehicle _bombVestAI;
		private _target = _vAI;

        {
			private _crewMember = ((crew (vehicle _x)) # 0);
			if (isnull _crewMember) then {continue};
			private _sideX = side (group _crewMember);
			if (_sideX in M9_bombVestAI_targetRestrictions) then {continue};
			if !(_crewMember in ([_bombVestAI] call M9_fnc_bombVestAI_getTargets)) then {continue};
            if (alive _crewMember) exitWith {_target = _crewMember};
        } forEach nearestObjects [vehicle _bombVestAI, ["Man", "Car", "Tank", "CAManBase", "StaticWeapon"], M9_bombVestAI_targetRadius];

        if (!isNull _target) then {
            private _targetVeh = vehicle _target;
            private _targetVehPos = getPos _targetVeh;
            'private _bombVestAIVeh = vehicle _bombVestAI;';

            _bombVestAI forgetTarget _target;
            _target forgetTarget _bombVestAI;
            _bombVestAI doMove _targetVehPos;
        };

        sleep 8;
    };
};

comment "Attach explosives to the unit and trigger explosion under conditions";
_bombVestAI spawn {
    private _bombVestAI = _this;

    comment "Create and attach the first explosive charge";
    private _charge1 = "ModuleExplosive_DemoCharge_F" createVehicle position vehicle _bombVestAI;
    _charge1 attachTo [_bombVestAI, [-0.1, 0.1, 0.15], "Pelvis"];
    _charge1 setVectorDirAndUp [[0.5, 0.5, 0], [-0.5, 0.5, 0]];

    comment "Create and attach the second explosive charge";
    private _charge2 = "ModuleExplosive_DemoCharge_F" createVehicle position vehicle _bombVestAI;
    _charge2 attachTo [_bombVestAI, [0, 0.15, 0.15], "Pelvis"];
    _charge2 setVectorDirAndUp [[1, 0, 0], [0, 1, 0]];

    comment "Create and attach the third explosive charge";
    private _charge3 = "ModuleExplosive_DemoCharge_F" createVehicle position vehicle _bombVestAI;
    _charge3 attachTo [_bombVestAI, [0.1, 0.1, 0.15], "Pelvis"];
    _charge3 setVectorDirAndUp [[0.5, -0.5, 0], [0.5, 0.5, 0]];

    comment "Reinforce unit behavior for final charge toward players";
    _bombVestAI allowFleeing 0;
    _bombVestAI setCombatMode "RED";
    _bombVestAI setSkill ["courage", 1];

    comment "Play random pain sound effect to signal final phase";
    playSound3D [
        selectRandom [
            "A3\sounds_f\characters\human-sfx\P03\Hit_Max_3.wss",
            "A3\sounds_f\characters\human-sfx\P04\Hit_Max_1.wss"
        ],
        _bombVestAI, false, getPosASL _bombVestAI, 5, 1, 200
    ];

    comment "Wait until players are within 16 meters or the unit is dead";

    waitUntil {
        (
            ({(vehicle _x) distance _bombVestAI < 16} count ([_bombVestAI] call M9_fnc_bombVestAI_getTargets) > 0)
            or (!alive _bombVestAI)
        )
    };

    comment "Play pain and phone ringing sounds before detonation";
    playSound3D [
        selectRandom [
            "A3\sounds_f\characters\human-sfx\P03\Hit_Max_3.wss",
            "A3\sounds_f\characters\human-sfx\P04\Hit_Max_1.wss"
        ],
        _bombVestAI, false, getPosASL _bombVestAI, 5, 1, 200
    ];
    playSound3D [
        "A3\Sounds_F_Enoch\Assets\Props\Sfx_RuggedPhone_Ringing_01.wss",
        _bombVestAI, false, getPosASL _bombVestAI, 5, 1, 200
    ];

    comment "Trigger the explosion sequence";
    sleep 1;
    deleteVehicle _charge2;
    deleteVehicle _charge3;
    _charge1 setDamage 1;

    comment "Apply area damage to nearby objects";
    {
		if (_x isKindOf 'Man') then {continue};
        private _damage = damage _x;
        private _newDamage = _damage + 0.5;
        _x setDamage _newDamage;
    } forEach nearestObjects [_bombVestAI, [], 17];

    comment "Ensure complete destruction of the unit";
    sleep 0.44;
    _bombVestAI setDamage 1;
    deleteVehicle _bombVestAI;
};

comment "Failsafe: delete the unit after 10 minutes if still alive";
_bombVestAI spawn {
    sleep (60 * 10);
    if (!isNull _this) then {
		waitUntil {
			(
				({(vehicle _x) distance _this < viewDistance} count allPlayers <= 0)
				or (!alive _this)
			)
		};
        deleteVehicle _this;
    };
};
