/*
	author: Hayashi POLPOX Takeyuki

	handles wildfire module system

	Arguments:
		0: Object - module object OR Array - position to create one if the mode is "fireCreate"
		1: Mode - see below
			"fireCreate" - creates the wild fire module in the designated place
			"init" - handles the initialization of the module like creation of particles
			"setIntensity" - sets the intensity level
			"getIntensity" - gets the intensity level

			"DebugOn" - enables the debug system for the module, will show the current fire situation
				note: if 0: Object is objNull, will apply this to every wildfire modules
			"DebugOff" - disables the debug system for the module
				note: if 0: Object is objNull, will apply this to every wildfire modules
				
			"AutoConnect" - connect selected wildfire modules and make influence network in Eden
			
		2: Arguments
			Array - if mode is "fireCreate" where [intensity (0-1 Number), area (1-50 number in meters), onExtinguishedScript (string),onIntensityChangedScript (string)]
			Number - if mode is "setIntensity" where 0-1 Number

		Or

		0: Mode - see below
			"DebugOn" - apply Debug on every wildfire modules
			"DebugOff" - remove Debug from every wildfire modules
			"AutoConnect" - connect selected wildfire modules and make influence network in Eden
	
	Return:
		Object - module object if "fireCreate"
		Number - wildFire intensity if "getIntensity"
*/
params ["_module","_mode","_args"];

//#define lxRF_fnc_wildFire compile preprocessFileLineNumbers "fn_wildfire.sqf"

// if you pass objNull, will apply debug things into every wildfire module
// or the entire _this is a string, do the same
if (
	(_this isEqualType "" and {_this == "DebugOn" or _this == "DebugOff"}) or
	(_module isEqualType "" and {_module == "DebugOn" or _module == "DebugOff"})
) exitWith {
	if (_this isEqualType "") then {
		_module = objNull ;
		_mode = _this ;
	} ;
	if (_this isEqualType []) then {
		_mode = _module ;
	} ;

	{
		[_x,_mode] call lxRF_fnc_wildFire
	} forEach allMissionObjects "Module_WildFire_RF";
};

if (
	(_this isEqualType "" and {_this == "AutoConnect"})
) then {
	_mode = _this ;
};

if (
	(_module isEqualType "" and {_module == "AutoConnect"})
) then {
	_mode = _module ;
};

call {
	if (_mode == "fireCreate") exitWith {
		if (isNil "_args") then {_args = []};
		_args params [
			["_intensity",0.3],
			["_area",5],
			["_onExtinguished","true"],
			["_onIntensityChanged","true"]
		];
		private _pos = _module;	// just change the name not to confuse
		private _group = call {
			// if there already is a logic group reuse it
			if (count (groups sideLogic) >= 1) exitWith {(groups sideLogic)#0};
			// if not create one
			createGroup sideLogic;
		};
		private _module = _group createUnit ["Module_WildFire_RF",_pos,[],0,"CAN_COLLIDE"]; 
		//_module setVariable ["BIS_fnc_initModules_disableAutoActivation",false,true];

		_module setVariable ["lxRF_FireIntensity",_intensity];
		_module setVariable ["lxRF_fireArea",_area,true];
		_module setVariable ["lxRF_OnExtinguished",_onExtinguished,true];
		_module setVariable ["lxRF_OnIntensityChanged",_onIntensityChanged,true];

		[_module,"Init",[_intensity,_area]] call lxRF_fnc_wildFire;
		_module
	};

	//if (!local _module) exitWith {};	// is this necessary?
	if (_mode == "init") exitWith {
		_args params ["_intensity","_area"];

		_module setVariable ["lxRF_fireArea",_area,true];

		#define EFFSCALE (_area)
		#define PARTSTEP (round (linearConversion [1,50,_area*_n/10,3,7,true]))

		private _pos = ASLToAGL getPosASL _module;
		// force snap into the ground
		_pos set [2,0] ;

		private _dirVel = {
			private _dist = sqrt (_PS distance2D _module) ;
			private _dir = _PS getDir _module ;

			[(sin _dir)*_dist*_this*(sqrt _area)/5,(cos _dir)*_dist*_this*(sqrt _area)/5,(0.25*sqrt _area * sqrt _intensity)/(_dist max 1)]
		};
		private _distAlpha = {
			private _dist = (_PS distance2D _module) ;

			_this apply {
				[_x#0,_x#1,_x#2,_x#3/(linearConversion [10,60,_dist,1,3,true])]
			} ;
		};

		private _PSFireLow = [];
		for "_n" from 0 to EFFSCALE step 8 do {
			for "_i" from (360/PARTSTEP) to 360 step (360/PARTSTEP) do {
				private _PS = "#particlesource" createVehicleLocal (_pos getPos [(0.3 + random 0.1) + _n,_i]);
				_PS setDropInterval -1;

				// if area is not so big, make some difference
				if (_area <= 5) then {
					_PS setParticleParams
					[
						["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 10, 32],"","Billboard",1,
						2,[0,0,0.5],0.5 call _dirVel,		// lifeTime, pos, vel
						0,0.050,0.043,0.05,			// rotation, weight, volume, rubbing
						[3,5],					// size
						[[0.5,0.5,0.5,0],[0.5,0.5,0.5,-0.3],[0.5,0.5,0.5,-0.1],[0.5,0.5,0.5,0.0]],
						// color
						[1,0.5],					// animSpeed
						0.1,0.1,					// randomDir/randomIntensity
						"","",						// scripts
						_PS,0,					// Object, angle
						false,-1,					// bounceOnSurface
						[[160*1.3,120*1.3,70*1.3,1]]					// emission
					];
				} else {
					_PS setParticleParams
					[
						["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 10, 32],"","Billboard",1,
						2,[0,0,0.5],0.25 call _dirVel,		// lifeTime, pos, vel
						0,0.050,0.043,0.05,			// rotation, weight, volume, rubbing
						[2 * (sqrt _area) / 3,4 * (sqrt _area) / 3],					// size
						[[0.5,0.5,0.5,0],[0.5,0.5,0.5,-0.6],[0.5,0.5,0.5,-0.3],[0.5,0.5,0.5,0.0]] call _distAlpha,
						// color
						[1,0.5],					// animSpeed
						0.1,0.1,					// randomDir/randomIntensity
						"","",						// scripts
						_PS,0,					// Object, angle
						false,-1,					// bounceOnSurface
						[[120,100,30,1]] call _distAlpha					// emission
					];
				} ;
				_PS setParticleRandom [
					0.3,						// lifeTime
					[0.3*EFFSCALE,0.3*EFFSCALE,0.1],[0.05,0.05,0.2],	// pos, vel
					0.1,0.1,[0,0,0,0.1],		// rotation, size, color
					0.1,0.1,					// directionPeriod, intensity
					0.1							// angle
				];
				//_PS setParticleFire [0.05,0.2 * EFFSCALE,0.5];
				_PSFireLow pushBack _PS;
			};
		} ;

		private _PSFire = [];
		//for "_n" from ((EFFSCALE-16) max 0) to (EFFSCALE-8 max 0) step 8 do {
			for "_i" from (360/6) to 360 step (360/6) do {
				private _PS = "#particlesource" createVehicleLocal (_pos getPos [(random [EFFSCALE*0.75,EFFSCALE*0.8,EFFSCALE*0.95]),_i]);
				_PS setDropInterval -1;

				// if area is not so big, make some difference
				if (_area <= 5) then {
					_PS setParticleParams
					[
						["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 10, 32],"","Billboard",1,
						2,[0,0,0.8],1.55 call _dirVel,		// lifeTime, pos, vel
						0,0.050,0.046,0.05,			// rotation, weight, volume, rubbing
						[6 * (sqrt _area) / 5,7 * (sqrt _area) / 5],					// size
						[[0.5,0.5,0.5,0],[0.5,0.5,0.5,-0.6],[0.5,0.5,0.5,-0.3],[0.5,0.5,0.5,-0.1],[0.5,0.5,0.5,0.0]],
						// color
						[1,0.5],					// animSpeed
						0.1,0.1,					// randomDir/randomIntensity
						"","",						// scripts
						_PS,0,					// Object, angle
						false,-1,					// bounceOnSurface
						[[160*1.3,120*1.3,70*1.3,1]]					// emission
					];
					_PS setParticleRandom [
						0.3,						// lifeTime
						[0.6*EFFSCALE^0.2,0.6*EFFSCALE^0.2,0.5],[0.05,0.05,0.2],	// pos, vel
						0.1,0.1,[0,0,0,0.1],		// rotation, size, color
						0.1,0.1,					// directionPeriod, intensity
						0.1							// angle
					];
				} else {
					_PS setParticleParams
					[
						["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 10, 32],"","Billboard",1,
						2 * (_area ^ 0.15),[0,0,0.5],1.7 call _dirVel,		// lifeTime, pos, vel
						0,0.050,0.043,0.05,			// rotation, weight, volume, rubbing
						[5.5 * (sqrt _area) / 5,6.5 * (_area ^ 0.65) / 5],					// size
						[[1,0.7,0.3,0],[1,0.7,0.3,-1.2],[1,0.7,0.3,-0.8],[1,0.7,0.3,-0.4],[1,0.7,0.3,0.0]] call _distAlpha,
						// color
						[1,0.5],					// animSpeed
						0.1,0.1,					// randomDir/randomIntensity
						"","",						// scripts
						_PS,0,					// Object, angle
						false,-1,					// bounceOnSurface
						[[120,100,30,1]] call _distAlpha					// emission
					];
					
					_PS setParticleRandom [
						0.3,						// lifeTime
						[1.5*EFFSCALE^0.5,1.5*EFFSCALE^0.5,0.5],[0.05,0.05,0.2],	// pos, vel
						0.1,0.1,[0,0,0,0.1],		// rotation, size, color
						0.1,0.1,					// directionPeriod, intensity
						0.1							// angle
					];
				} ;
				//_PS setParticleFire [0.10,0.4 * EFFSCALE,0.5];
				_PSFire pushBack _PS;
			};
		//};

		private _PSFireBig = [];
		//for "_n" from ((EFFSCALE-16) max 0) to (EFFSCALE-6 max 0) step 6 do {
			for "_i" from (360/3) to 360 step (360/3) do {
				private _PS = "#particlesource" createVehicleLocal (_pos getPos [EFFSCALE*0.15,_i]);
				//private _PS = "#particlesource" createVehicleLocal (_pos);
				_PS setDropInterval -1;

				// if area is not so big, make some difference
				if (_area <= 5) then {
					_PS setParticleParams
					[
						["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 10, 32],"","Billboard",1,
						1.0,[0,0,0.5],[0,0,0.1],		// lifeTime, pos, vel
						0,0.050,0.065,0.05,			// rotation, weight, volume, rubbing
						[12 * (sqrt _area) / 5,7 * (sqrt _area) / 5],					// size
						[[1,0.7,0.3,0],[1,0.7,0.3,-4.5],[1,0.7,0.3,-1],[1,0.7,0.3,-0.25],[1,0.7,0.3,0.0]],
						// color
						[1.2,0.7],					// animSpeed
						0.1,0.02,					// randomDir/randomIntensity
						"","",						// scripts
						_PS,0,					// Object, angle
						false,-1,					// bounceOnSurface
						[[120*2.8,100*2.8,30*2.8,1]]					// emission
					];
					_PS setParticleRandom [
						0.4,						// lifeTime
						[0.2*EFFSCALE^0.4,0.2*EFFSCALE^0.4,0.5],[0.05,0.05,0.7],	// pos, vel
						0.1,0.3,[0,0,0,0.4],		// rotation, size, color
						0.1,0.1,					// directionPeriod, intensity
						0.1							// angle
					];
				} else {
					_PS setParticleParams [
						["\A3\data_f\ParticleEffects\Universal\Explosion_4x4.p3d", 4, 1, 12, 0],"","Billboard",1,
						(linearConversion [0,50,_area,1.2,1.5]),[0,0,-0.5],[0,0,1.5],		// lifeTime, pos, vel
						5,0.050,0.065+(linearConversion [0,50,_area,0,0.02]),0.05,			// rotation, weight, volume, rubbing
						[4 * (_area ^ 0.45) / 5,20 * (_area ^ 0.55) / 5],					// size
						[[1,0.7,0.3,0],[1,0.7,0.3,-0.1],[1,0.7,0.3,-5],[1,0.7,0.3,-0.5],[1,0.7,0.3,0.0]],
						// color
						[0.7],					// animSpeed
						0.1,0.02,					// randomDir/randomIntensity
						"","",						// scripts
						_PS,0,					// Object, angle
						false,-1,					// bounceOnSurface
						[[180*2.8,100*2.8,30*2.8,1]]					// emission
					];
					_PS setParticleRandom [
						(linearConversion [0,50,_area,0.2,0.4]),						// lifeTime
						[0.3*EFFSCALE^0.8,0.3*EFFSCALE^0.8,0.5],[0.3,0.3,0.2],	// pos, vel
						10,0.02 * (_area ^ 0.55),[0,0,0,0.4],		// rotation, size, color
						0.1,0.1,					// directionPeriod, intensity
						pi*2							// angle
					];
				} ;
				//_PS setParticleFire [0.15,0.5 * EFFSCALE,0.5];
				_PS setParticleCircle [0.6 * EFFSCALE,[0,-1 * EFFSCALE^0.8,0]];
				_PSFireBig pushBack _PS;
			};			
		//};

		private _PSFireSpark = [];
		for "_n" from 4 to EFFSCALE max 4 step 12 do {
			for "_i" from (360/PARTSTEP) to 360 step (360/PARTSTEP) do {
				private _PS = "#particlesource" createVehicleLocal (_pos getPos [EFFSCALE*0.15,_i]);
				_PS setDropInterval -1;
				
				_PS setParticleParams
				[
					["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 13, 2, 0],"","Billboard",1,
					3,[0,0,0.5],0.1 call _dirVel,		// lifeTime, pos, vel
					0,0.050,0.07,0.05,			// rotation, weight, volume, rubbing
					[0,0.4,0.1,0],					// size
					[[1,0.3,0.1,-5]],
					// color
					[1000],					// animSpeed
					0.02,0.1,					// randomDir/randomIntensity
					"","",						// scripts
					_PS,0,					// Object, angle
					false,-1,					// bounceOnSurface
					[[50,15,5,1]]					// emission
				];
				_PS setParticleRandom [
					2,						// lifeTime
					[0.6*EFFSCALE,0.6*EFFSCALE,0.1],[1.2,1.2,0.3],	// pos, vel
					0.1,0.4,[0,0,0,0.1],		// rotation, size, color
					0.02,0.3,					// directionPeriod, intensity
					0.1							// angle
				];
				//_PS setParticleFire [0.05,0.2 * EFFSCALE,0.5];
				_PSFireSpark pushBack _PS;
			};
		} ;


		private _PSSmokeSmall = "#particlesource" createVehicleLocal _pos;
		_PSSmokeSmall setDropInterval -1;
		_PSSmokeSmall setParticleParams
		[
			["\A3\data_f\ParticleEffects\Universal\Universal_02.p3d", 8, 0, 40],"","Billboard",1,
			4,[0,0,0],[0,0,2.5],		// lifeTime, pos, vel
			0,0.050,0.065,0.06,			// rotation, weight, volume, rubbing
			[3 * (sqrt _area),4 * (sqrt _area),8 * (sqrt _area)],					// size
			[[0.3,0.3,0.3,0],[0.4,0.4,0.4,0.1],[0.5,0.5,0.5,0.05],[0.6,0.6,0.6,0.01],[0.7,0.7,0.7,0.0]],
			// color
			[1,0.3],					// animSpeed
			0.1,0.3,					// randomDir/randomIntensity
			"","",						// scripts
			_PSSmokeSmall,0,					// Object, angle
			false,-1,					// bounceOnSurface
			[[0,0,0,0]]					// emission
		];
		_PSSmokeSmall setParticleRandom [
			0.5,						// lifeTime
			[0.7*EFFSCALE,0.7*EFFSCALE,1.5],[0.2,0.2,1],	// pos, vel
			0.5,0.2,[0.05,0.05,0.05,0.1],		// rotation, size, color
			0.1,0.1,					// directionPeriod, intensity
			pi*2							// angle
		];

		private _PSSmoke = "#particlesource" createVehicleLocal _pos;
		_PSSmoke setDropInterval -1;
		_PSSmoke setParticleParams
		[
			["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 12, 13, 0],"","Billboard",1,
			8,[0,0,2],[0,0,1.5],		// lifeTime, pos, vel
			0,0.050,0.075,0.06,			// rotation, weight, volume, rubbing
			[10,20,40],					// size
			[[0.1,0.1,0.1,0],[0.1,0.1,0.1,0.4],[0.1,0.1,0.1,0.2],[0.2,0.2,0.2,0.1],[0.3,0.3,0.3,0.0]],
			// color
			[1000],					// animSpeed
			0.1,0.5,					// randomDir/randomIntensity
			"","",						// scripts
			_PSSmoke,0,					// Object, angle
			false,-1,					// bounceOnSurface
			[[0,0,0,0]]					// emission
		];
		_PSSmoke setParticleRandom [
			3.5,						// lifeTime
			[0.6*EFFSCALE,0.6*EFFSCALE,1.5],[0.6,0.6,1.5],	// pos, vel
			0.5,0.5,[0.03,0.03,0.03,0.2],		// rotation, size, color
			0.1,0.1,					// directionPeriod, intensity
			pi*2							// angle
		];
		//_PSSmoke setDropInterval 0.05;

		private _PSSmokeBig = "#particlesource" createVehicleLocal _pos;
		_PSSmokeBig setDropInterval -1;
		_PSSmokeBig setParticleParams
		[
			//["\A3\data_f\ParticleEffects\Universal\Universal_02.p3d", 8, 0, 40],"","Billboard",1,
			["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 12, 13, 0],"","Billboard",1,
			12,[0,0,5],[0,0,1.5],		// lifeTime, pos, vel
			0,0.050,0.085,0.06,			// rotation, weight, volume, rubbing
			[15,45],					// size
			[[0.2,0.2,0.2,0],[0.2,0.2,0.2,0.8],[0.2,0.2,0.2,0.6],[0.3,0.3,0.3,0.4],[0.4,0.4,0.4,0.03],[0.7,0.7,0.7,0.0]],
			// color
			[1000],					// animSpeed
			0.1,0.6,					// randomDir/randomIntensity
			"","",						// scripts
			_PSSmokeBig,0,					// Object, angle
			false,-1,					// bounceOnSurface
			[[15,8,2,0],[0,0,0,0],[0,0,0,0]]					// emission
		];
		_PSSmokeBig setParticleRandom [
			2,						// lifeTime
			[0.7*EFFSCALE,0.7*EFFSCALE,1.5],[1,1,2],	// pos, vel
			6.5,0.5,[0.03,0.03,0.03,0.2],		// rotation, size, color
			0.1,0.1,					// directionPeriod, intensity
			pi*2							// angle
		];

		private _PSSmokeBigFar = "#particlesource" createVehicleLocal _pos;
		_PSSmokeBigFar setDropInterval -1;
		_PSSmokeBigFar setParticleParams
		[
			//["\A3\data_f\ParticleEffects\Universal\Universal_02.p3d", 8, 0, 40],"","Billboard",1,
			["\A3\data_f\ParticleEffects\Universal\Universal.p3d", 16, 12, 13, 0],"","Billboard",1,
			40,[0,0,25],[0,0,25],		// lifeTime, pos, vel
			0,0.050,0.085,0.06,			// rotation, weight, volume, rubbing
			[35,60],					// size
			[[0.2,0.2,0.2,0],[0.2,0.2,0.2,0.5],[0.3,0.3,0.3,0.2],[0.4,0.4,0.4,0.03],[0.7,0.7,0.7,0.0]],
			// color
			[1000],					// animSpeed
			0.1,0.6,					// randomDir/randomIntensity
			"","",						// scripts
			_PSSmokeBigFar,0,					// Object, angle
			false,-1,					// bounceOnSurface
			[[15,8,2,0],[0,0,0,0],[0,0,0,0]]					// emission
		];
		_PSSmokeBigFar setParticleRandom [
			5,						// lifeTime
			[0.7*EFFSCALE,0.7*EFFSCALE,15],[6,6,12],	// pos, vel
			6.5,0.8,[0.03,0.03,0.03,0.2],		// rotation, size, color
			0.1,0.1,					// directionPeriod, intensity
			pi*2							// angle
		];

		private _PSRefract = "#particlesource" createVehicleLocal _pos;
		_PSRefract setDropInterval -1;
		_PSRefract setParticleParams
		[
			["\A3\data_f\ParticleEffects\Universal\refract.p3d", 1, 0, 1],"","Billboard",1,
			4,[0,0,0],[0,0,3.5],		// lifeTime, pos, vel
			0,0.050,0.07,0.06,			// rotation, weight, volume, rubbing
			[8,16],					// size
			[[1,1,1,0],[1,1,1,0.4],[1,1,1,0.2],[1,1,1,0.1],[1,1,1,0.0]],
			// color
			[0],					// animSpeed
			0.1,0.3,					// randomDir/randomIntensity
			"","",						// scripts
			_PSRefract,0,					// Object, angle
			false,-1,					// bounceOnSurface
			[[0,0,0,0]]					// emission
		];
		_PSRefract setParticleRandom [
			2.5,						// lifeTime
			[1.2*EFFSCALE,1.2*EFFSCALE,1.5],[0.2,0.2,0.4],	// pos, vel
			0.5,0.5,[0.03,0.03,0.03,0.2],		// rotation, size, color
			0.1,0.1,					// directionPeriod, intensity
			pi*2							// angle
		];
		//_PSRefract setDropInterval 0.2;

		private _lightSource = "#lightpoint" createVehicleLocal ASLToAGL getPosASL _module;
		_lightSource setLightColor [2,1.5,0.3];
		_lightSource setLightAmbient [4,0.7,0.1];
		//_lightSource setLightBrightness 4;
		_lightSource setLightDayLight true;
		_lightSource setLightAttenuation [0.3*EFFSCALE, 0, 0.1/EFFSCALE, 0.1/EFFSCALE];

		private _PSFireDamageBig = [];
		for "_n" from 0 to EFFSCALE step 5 do {
			for "_i" from (360/PARTSTEP*2) to 360 step (360/PARTSTEP*2) do {
				private _PS = "#particlesource" createVehicleLocal (_pos getPos [0.3 * (_area),_i]);
				_PS setParticleParams
				[
					["\a3\weapons_f\empty.p3d", 1, 0, 1],"","SpaceObject",1,
					0,[0,0,0],[0,0,0],		// lifeTime, pos, vel
					0,1.277,1,0,		// rotation, weight, volume, rubbing
					[0],					// size
					[],
					// color
					[],					// animSpeed
					0,0,					// randomDir/randomIntensity
					"","",						// scripts
					_PS					// Object, angle
				];
				_PS setDropInterval 3;
				
				// debug
				/*_PS setParticleParams
				[
					["\A3\Structures_F_Heli\VR\Helpers\Sign_sphere100cm_F.p3d", 1, 0, 1],"","SpaceObject",1,
					3,[0,0,0],[0,0,0],		// lifeTime, pos, vel
					0,1.277,1,0,		// rotation, weight, volume, rubbing
					[4*(sqrt _area)],					// size
					[],
					// color
					[],					// animSpeed
					0,0,					// randomDir/randomIntensity
					"","",						// scripts
					_PS,0,					// Object, angle
					false,-1					// bounceOnSurface
				];
				_PS setDropInterval 3;*/
				
				//_PS setParticleFire [1.6,3*(sqrt _area),0.15];
				_PSFireDamageBig pushBack _PS;
			};
		} ;

		private _PSFireDamage = [];
		for "_n" from 0 to EFFSCALE step 5 do {
			for "_i" from (360/PARTSTEP/1.5) to 360 step (360/PARTSTEP/1.5) do {
				private _PS = "#particlesource" createVehicleLocal (_pos getPos [0.75 * (_area),_i]);			
				_PS setParticleParams
				[
					["\a3\weapons_f\empty.p3d", 1, 0, 1],"","SpaceObject",1,
					0,[0,0,0],[0,0,0],		// lifeTime, pos, vel
					0,1.277,1,0,		// rotation, weight, volume, rubbing
					[0],					// size
					[],
					// color
					[],					// animSpeed
					0,0,					// randomDir/randomIntensity
					"","",						// scripts
					_PS					// Object, angle
				];
				_PS setDropInterval 3;

				// debug
				/*_PS setParticleParams
				[
					["\A3\Structures_F_Heli\VR\Helpers\Sign_sphere100cm_F.p3d", 1, 0, 1],"","SpaceObject",1,
					3,[0,0,0],[0,0,0],		// lifeTime, pos, vel
					0,1.277,1,0,		// rotation, weight, volume, rubbing
					[2.5*(sqrt _area)],					// size
					[],
					// color
					[],					// animSpeed
					0,0,					// randomDir/randomIntensity
					"","",						// scripts
					_PS,0,					// Object, angle
					false,-1					// bounceOnSurface
				];
				_PS setDropInterval 3;*/
				
				//_PS setParticleFire [0.8,1.5*(sqrt _area),0.15];
				_PSFireDamage pushBack _PS;
			};
		} ;

		// store every effects into one
		_module setVariable ["lxRF_fireEffects",[
			_PSFireLow,
			_PSFire,
			_PSFireBig,
			_PSSmokeSmall,
			_PSSmoke,
			_PSSmokeBig,
			_PSRefract,
			_lightSource,
			objNull,
			_PSFireDamageBig,
			_PSFireDamage,
			_PSSmokeBigFar,
			_PSFireSpark
		]];

		_module setVariable ["lxRF_explosionRnd",time + 30 + random 120];

		// handle some events that has to be ran every frame
		private _EH = addMissionEventHandler ["Draw3D",{
			if (isGamePaused or accTime == 0) exitWith {};
			//_thisArgs params ["_module"];
			// workaround until _thisArgs issue is fixed
			private _module = (missionNamespace getVariable [format ["lxRF_fnc_wildFire_EHVar_%1",_thisEventHandler],objNull]) ;
			_module getVariable ["lxRF_fireEffects",[]] params [
				"",
				"",
				"",
				"",
				"",
				"",
				"",
				"_lightSource"
			];
			private _intesityLocal = _module getVariable ["lxRF_fire_lightIntensity",-1];
			private _intesity = _module getVariable ["lxRF_fireIntensity",-1];
			private _area = _module getVariable ["lxRF_fireArea",-1];
			private _randomArea = _area * 0.2;

			// adjust the light scale depends on the actual intensity
			_intesityLocal = (_intesity-_intesityLocal)*((0.0002*diag_deltaTime*60*accTime) max 0.01) + _intesityLocal;
			_module setVariable ["lxRF_fire_lightIntensity",_intesityLocal];

			if (_intesityLocal > 0.1) then {
				_lightSource setLightBrightness (linearConversion [0.1,1,_intesityLocal,0.03,0.6,true] + random [0.0,0.01,0.02]);
				_lightSource setPosWorld ((getPosWorld _module) vectorAdd [random [-_randomArea,0,_randomArea],random [-_randomArea,0,_randomArea],random [-_randomArea,0,_randomArea]]);
			} else {
				_lightSource setLightBrightness 0;
			};

			private _explosionRnd = _module getVariable ["lxRF_explosionRnd",-1];

			// sometimes cause an "explody" big flame
			if (_intesity > 0.3 and _area > 5 and time > _explosionRnd) then {
			//if (true) then {
				private _timeRand = random [0.8,1,1.6] ;
				private _dirLocal = random 360 ;
				private _alphaCoef = call {
					if (time < _explosionRnd + (_intesity*0.8)) then {
						linearConversion [_explosionRnd+(_intesity*0.5),_explosionRnd+(_intesity*1.5),time,0,1,true] ;
					} else {
						linearConversion [_explosionRnd+(_intesity*1.5),_explosionRnd+(_intesity*4.5),time,1,0,true] ;
					} ;
				};
				if (random 1 < (0.6 * accTime * diag_deltaTime * 60)) then {
					private _distLocal = _area ^ (random [0.2,0.75,0.95]) ;
					drop [
						["\A3\data_f\ParticleEffects\Universal\Explosion_4x4.p3d", 4, 0, 16, 0],"","Billboard",1,
						((linearConversion [0,50,_area,0.5 + random 1.0,1.5 + random 1.5])) * random [0.8,1,1.6],
						[_distLocal*sin _dirLocal + random [-3,0,3],_distLocal*cos _dirLocal + random [-3,0,3],0.5-random 1],
						[_distLocal*-0.6*sin _dirLocal + random [-2,0,2],_distLocal*-0.6*cos _dirLocal + random [-2,0,2],((4+random 2)*_alphaCoef)*_area^0.1],		// lifeTime, pos, vel
						10 - random 20,0.050,0.043+(linearConversion [0,50,_area,0.08*_alphaCoef,0.15*_alphaCoef]),0.05,			// rotation, weight, volume, rubbing
						[(7+random 3) * (_area ^ 0.55) / 5,(12+random 8) * (_area ^ 0.55) / 5],					// size
						[[1,0.7,0.3,0],[1,0.7,0.3,-0.1*_alphaCoef],[1,0.7,0.3,-2*_alphaCoef],[1,0.7,0.3,-1*_alphaCoef],[1,0.7,0.3,-0.2*_alphaCoef],[1,0.7,0.3,0.0]],
						// color
						[0.8+random 0.4,0.3],					// animSpeed
						0.1,0.7,					// randomDir/randomIntensity
						"","",						// scripts
						_module,random pi*4,					// Object, angle
						false,-1,					// bounceOnSurface
						[[180*4*_alphaCoef,100*4*_alphaCoef,30*4*_alphaCoef,1]]					// emission
					];
				} ;
				if (time > _explosionRnd+(_intesity*6.5)) then {
					_module setVariable ["lxRF_explosionRnd",time + 30 + random 120];
				} ;
			} ;

			// if the module's simulation is disabled, don't do the influence part
			if !(simulationEnabled _module) exitWith {};

			// influenced by other syncd modules
			private _synced = (synchronizedObjects _module) ;
			if (count _synced != 0) then {
				// list all synced modules
				private _syncIntensity = (_synced apply {(_x getVariable ["lxRF_fireIntensity",-1])}) ;
				private _max = ((selectMax _syncIntensity) - 0.25) max 0 ;

				// check if there is more intense fire
				if (_max > _intesity) then {
					private _diff = (_max - _intesity) ;
					[_module,"setIntensity",(_intesity + (_diff*diag_deltaTime*60*accTime*0.00007)) min 1 max 0] call lxRF_fnc_wildFire; 
				} ;
			} ;
		}/*,[_module]*/];

		missionNamespace setVariable [format ["lxRF_fnc_wildFire_EHVar_%1",_EH],_module] ;

		_module setVariable ["lxRF_fire_lightIntensity",_intensity];
		_module setVariable ["lxRF_fire_MEH",_EH];
		_module setVariable ["lxRF_fire_enabled",true];

		// do not run onIntensityChanged script in init
		private _intensityChanging = true;
		[_module,"setIntensity",_intensity] call lxRF_fnc_wildFire; 

		// defines how it behaves when the module itself has been removed
		_module addEventHandler ["Deleted",{
			params ["_module"];
			_module getVariable ["lxRF_fireEffects",[
				[],
				[],
				[],
				objNull,
				objNull,
				objNull,
				objNull,
				objNull,
				objNull,
				[],
				[],
				objNull,
				[]
			]] params [
				"_PSFireLow",
				"_PSFire",
				"_PSFireBig",
				"_PSSmokeSmall",
				"_PSSmoke",
				"_PSSmokeBig",
				"_PSRefract",
				"_lightSource",
				"_sound",
				"_PSFireDamageBig",
				"_PSFireDamage",
				"_PSSmokeBigFar",
				"_PSFireSpark"
			];

			{
				if (typeName _x == "ARRAY") then {
					_x apply {deleteVehicle _x};
				} else {
					deleteVehicle _x;
				};
			} forEach [
				_PSFireLow,
				_PSFire,
				_PSFireBig,
				_PSSmokeSmall,
				_PSSmoke,
				_PSSmokeBig,
				_PSRefract,
				_lightSource,
				_sound,
				_PSFireDamageBig,
				_PSFireDamage,
				_PSSmokeBigFar,
				_PSFireSpark
			];

			// bye-bye!
			removeMissionEventHandler ["Draw3D",_module getVariable ["lxRF_fire_MEH",-1]];
			
			// remove map debug too, if you have one
			private _map = (findDisplay 12 displayCtrl 51);
			private _debugItems = _map getVariable ["lxRF_wildfire_debug",[]];
			_debugItems deleteAt (_debugItems find _module);
			_map setVariable ["lxRF_wildfire_debug",_debugItems];
		}];
	};
	if (_mode == "setIntensity") exitWith {
		private _intensity = _args;

		_module getVariable ["lxRF_fireEffects",[
			[],
			[],
			[],
			objNull,
			objNull,
			objNull,
			objNull,
			objNull,
			objNull,
			[],
			[],
			objNull,
			[]
		]] params [
			"_PSFireLow",
			"_PSFire",
			"_PSFireBig",
			"_PSSmokeSmall",
			"_PSSmoke",
			"_PSSmokeBig",
			"_PSRefract",
			"_lightSource",
			"_sound",
			"_PSFireDamageBig",
			"_PSFireDamage",
			"_PSSmokeBigFar",
			"_PSFireSpark"
		];

		private _area = _module getVariable ["lxRF_fireArea",-1];
		private _pos = getPosWorld _module ;

		#define EFFSCALEINTENSITYFIRE (sqrt (_pos distance2D _x)/3.5 * (3/sqrt EFFSCALE))
		#define EFFSCALEINTENSITY ((EFFSCALE^0.8))
		#define PARTSTEP (round (linearConversion [1,50,_area/30,1,10]))

		if (_intensity > 0.1) then {
			_PSFireDamage apply {_x setParticleFire [linearConversion [0.1,1,_intensity,0.4,0.7],2.25*(sqrt _area),0.05]} ;
			_PSFireDamageBig apply {_x setParticleFire [linearConversion [0.1,1,_intensity,0.6,1.6],2.25*(sqrt _area),0.05]} ;

			_PSFireLow apply {
				_x setDropInterval ((linearConversion [0.1,0.3,_intensity,0.8 + random 0.4,0.1 + random 0.05]*PARTSTEP) / EFFSCALEINTENSITYFIRE);
				//_x setParticleFire [0.25 * 3,0.4 * EFFSCALE,0.1];
			};
		} else {
			_PSFireLow apply {
				_x setDropInterval -1;
				//_x setParticleFire [0.25 * 3,0.4 * EFFSCALE,0.1];
			};
		};

		if (_intensity > 0.3) then {
			_PSFire apply {
				_x setDropInterval (((linearConversion [0.3,0.6,_intensity,1 + random 1,0.3 + random 0.3,true]*PARTSTEP) / EFFSCALEINTENSITYFIRE)/(15/count _PSFire));
				//_x setParticleFire [0.50 * 3,0.4 * EFFSCALE,0.1];
			};
			_PSFireSpark apply {
				_x setDropInterval -1;
			};
			_PSSmoke setDropInterval (linearConversion [0.3,0.5,_intensity,8,1.5,true]) / EFFSCALEINTENSITY;
			_PSFireBig apply {
				_x setDropInterval (((linearConversion [0.3,1,_intensity,5,1.5]*PARTSTEP) / (EFFSCALEINTENSITY ^ 0.8)) + random 0.1)
			};
			_PSSmokeBigFar setDropInterval (linearConversion [0.3,1,_intensity,6,2]) / EFFSCALEINTENSITY;
			
			_PSFireLow apply {
				_x setDropInterval (((linearConversion [0.3,0.6,_intensity,0.1 + random 0.05,1.3 + random 0.05]*PARTSTEP) / EFFSCALEINTENSITYFIRE)/(15/count _PSFireLow))
				//_x setParticleFire [0.25 * 3,0.4 * EFFSCALE,0.1];
			};
		} else {
			_PSFire apply {
				_x setDropInterval -1;
				//_x setParticleFire [0,0,-1];
			};	// suppress
			_PSFireSpark apply {
				_x setDropInterval (((0.02 + random 0.03)*PARTSTEP * (count _PSFireSpark)^0.6));
			};
			//_lightSource setLightBrightness 0;
			_PSFireBig apply {
				_x setDropInterval -1;
				//_x setParticleFire [0,0,-1];
			};	// suppress
			_PSSmokeBigFar setDropInterval -1;
			_PSSmoke setDropInterval -1;	// suppress
		};

		if (_intensity > 0) then {
			_PSRefract setDropInterval (linearConversion [0,1,_intensity,4,0.3]) / EFFSCALEINTENSITY;
			if (_intensity < 0.5) then {
				_PSSmokeSmall setDropInterval (linearConversion [0,0.5,_intensity,1,0.3,true]) / EFFSCALEINTENSITY;
				_PSSmokeBig setDropInterval -1;	// suppress
			} else {
				_PSSmokeSmall setDropInterval (linearConversion [0.5,0.9,_intensity,0.3,10,true]) / EFFSCALEINTENSITY;
				_PSSmokeBig setDropInterval (linearConversion [0.5,1,_intensity,8,4]) / EFFSCALEINTENSITY;
			};
		} else {
			{
				if (typeName _x == "ARRAY") then {
					_x apply {_x setDropInterval -1};
				} else {
					_x setDropInterval -1;
				};
			} forEach [
				_PSFireLow,
				_PSFire,
				_PSFireBig,
				_PSSmokeSmall,
				_PSSmoke,
				_PSSmokeBig,
				_PSRefract,
				_PSFireDamageBig,
				_PSFireDamage,
				_PSSmokeBigFar,
				_PSFireSpark
			];
		};
		

		// add sound
		private _updateSound = {
			_module setVariable ["lxRF_fireEffects",[
				_PSFireLow,
				_PSFire,
				_PSFireBig,
				_PSSmokeSmall,
				_PSSmoke,
				_PSSmokeBig,
				_PSRefract,
				_lightSource,
				_sound,
				_PSFireDamageBig,
				_PSFireDamage,
				_PSSmokeBigFar,
				_PSFireSpark
			]] ;
		} ;

		if (isNull _sound) then {
			call {
				if (_intensity > 0.7) exitWith {
					_sound = createSoundSource ["rf_sound_wildFire3",getPosATL _module,[],0] ;
					call _updateSound ;
				} ;
				if (_intensity > 0.5) exitWith {
					_sound = createSoundSource ["rf_sound_wildFire2",getPosATL _module,[],0] ;
					call _updateSound ;
				} ;
				if (_intensity > 0.2) exitWith {
					_sound = createSoundSource ["rf_sound_wildFire1",getPosATL _module,[],0] ;
					call _updateSound ;
				} ;
			} ;
		} else {
			call {
				if (_intensity > 0.7 and typeOf _sound != "rf_sound_wildFire3") exitWith {
					deleteVehicle _sound ;
					_sound = createSoundSource ["rf_sound_wildFire3",getPosATL _module,[],0] ;
					call _updateSound ;
				} ;
				if (_intensity > 0.5 and typeOf _sound != "rf_sound_wildFire2") exitWith {
					deleteVehicle _sound ;
					_sound = createSoundSource ["rf_sound_wildFire2",getPosATL _module,[],0] ;
					call _updateSound ;
				} ;
				if (_intensity > 0.3 and typeOf _sound != "rf_sound_wildFire1") exitWith {
					deleteVehicle _sound ;
					_sound = createSoundSource ["rf_sound_wildFire1",getPosATL _module,[],0] ;
					call _updateSound ;
				} ;
				deleteVehicle _sound ;
			} ;
		} ;

		// to prevent if one tries to overwrite the intensity within the onIntensityChanged so will result a crash
		if !(isNil "_intensityChanging") exitWith {
			//diag_log "failsafe worked";
		};
		private _intensityChanging = true;

		// run the intensityChanged script
		private _scriptReturn = [
			_module,
			[_module,"GetIntensity"] call lxRF_fnc_wildFire,
			_intensity
		] call compile (_module getVariable ["lxRF_OnIntensityChanged",""]);

		if (!isNil "_scriptReturn" and {_scriptReturn isEqualType 0} and {_scriptReturn > 0 and 1 > _scriptReturn}) then {
			_intensity = _scriptReturn;
		};

		// if the fire has been extinguished, run a code. Also, it will run only once
		if (_intensity <= 0 and !(_module getVariable ["lxRF_HasExtinguished",false])) then {
			_module setVariable ["lxRF_HasExtinguished",true];
			[_module] call compile (_module getVariable ["lxRF_OnExtinguished",""]);
		};
		
		// set the intensity result
		if (local _module) then {
			_module setVariable ["lxRF_fireIntensity",_intensity max 0 min 1,true];
		};
	};
	if (_mode == "getIntensity") exitWith {
		_module getVariable ["lxRF_fireIntensity",-1];
	};

	if (_mode == "DebugOn") exitWith {
		// debug thing. will show the intensity number on the fly

		// don't run the same debug more than once!
		if (_module getVariable ["lxRF_wildfire_debug",-1] != -1) exitWith {};

		private _EH = addMissionEventHandler ["Draw3D",{
			if (isGamePaused or !isGameFocused) exitWith {};
			_thisArgs params ["_module"];

			// if the module is no more remove EH
			if (isNull _module) exitWith {removeMissionEventHandler ["Draw3D",_thisEventHandler]};

			if (positionCameraToWorld [0,0,0] distance getPosATL _module > 1000) exitWith {};	// don't show it if too far away

			private _intensity = [_module,"getIntensity"] call lxRF_fnc_wildFire;
			private _area = _module getVariable ["lxRF_fireArea",-1];

			drawIcon3D [
				"",
				[0.6,1,0,1],
				ASLToAGL getPosASLVisual _module,
				0,0,0,
				format ["Int: %1 / Area: %2 m",_intensity toFixed 2,_area toFixed 1],
				2,0.03,
				"EtelkaMonospacePro"
			];

			// draw in map too
			if (visibleMap) then {
			};
		},[_module]];

		private _map = (findDisplay 12 displayCtrl 51);
		private _debugItems = _map getVariable ["lxRF_wildfire_debug",[]];

		if (count _debugItems == 0) then {
			_map ctrlAddEventHandler ["Draw",{
				params ["_map"];
				{
					private _intensity = [_x,"getIntensity"] call lxRF_fnc_wildFire;
					private _area = _x getVariable ["lxRF_fireArea",-1];
					_map drawEllipse [
						getPosWorld _x,_area,_area,0,[0.6,1,1,1],"#(rgb,8,8,3)color(1,1,1,0.3)"
					];
					_map drawIcon [
						"#(rgb,1,1,1)color(1,1,1,1)",[0,1,0,1],_x,0,0,0,_intensity toFixed 2,2,0.05,"EtelkaMonospacePro","center"
					];
				} forEach (_map getVariable ["lxRF_wildfire_debug",[]]);
			}];
		};
		_debugItems pushBackUnique _module;
		_map setVariable ["lxRF_wildfire_debug",_debugItems];

		_module setVariable ["lxRF_wildfire_debug",_EH];
	};

	if (_mode == "DebugOff") exitWith {
		// remove debug
		removeMissionEventHandler ["Draw3D",
			_module getVariable ["lxRF_wildfire_debug",-1]
		];
		private _map = (findDisplay 12 displayCtrl 51);
		private _debugItems = _map getVariable ["lxRF_wildfire_debug",[]];
		_debugItems deleteAt (_debugItems find _module);
		_map setVariable ["lxRF_wildfire_debug",_debugItems];
	};

	if (_mode == "AutoConnect" and is3DEN) exitWith {
		// make/overwrite connection network in Eden for intensity influence
		collect3DENHistory {
			// find every selected wildfire modules
			private _fires = (get3DENSelected "logic") select {typeOf _x == "Module_WildFire_RF"} ;

			{
				// remove existed connections
				remove3DENConnection ["Sync",_fires,_x] ;
				private _curFire = _x ;

				// select near fires
				private _nearFires = _fires select {_x distance2D _curFire < ((_curFire getVariable ["lxRF_fireArea",-1])*2.5)} ;
				// and connect
				add3DENConnection ["Sync",_nearFires,_x] ;
			} forEach _fires ;
		} ;
	};
};