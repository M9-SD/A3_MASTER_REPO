/*
	author: Hayashi POLPOX Takeyuki

	handles default wildfire module behavior
*/

params ["_mode","_args"] ;
_args params ["_logic","_activated"];

// if is Eden Editor make preview thingie
if (is3DEN) exitWith {
	// if the thing is initialized or nuh
	if (isNull (_logic getVariable ["lxRF_wildFire_EdenPreview",objNull])) then {
		// make preview object
		private _previewCircle = createSimpleObject ["lxRF\functions_rf\ui\data\wildFire_area.p3d",[0,0,0]] ;
		_logic setVariable ["lxRF_wildFire_EdenPreview",_previewCircle] ;
		{
			_logic addEventHandler [_x,{
				params ["_logic"] ;
				// move the preview and scale it accordingly
				private _previewCircle = _logic getVariable ["lxRF_wildFire_EdenPreview",objNull] ;
				_previewCircle setPosWorld getPosWorld _logic ;
				_previewCircle setObjectScale ((_logic get3DENAttribute "lxRF_module_WildFire_FireArea")#0) ;
			}] ;
		} forEach ["AttributesChanged3DEN","Dragged3DEN"] ;
		_logic addEventHandler ["UnregisteredFromWorld3DEN",{
			params ["_logic"] ;
			// move the preview and scale it accordingly
			private _previewCircle = _logic getVariable ["lxRF_wildFire_EdenPreview",objNull] ;
			_previewCircle hideObject true ;
		}] ;
		// hide until we need to see
		_previewCircle hideObject !(_logic in (get3DENSelected "logic")) ;
	} ;
	true
} ;

if (_activated) then {
	private _intensity = _logic getVariable ["lxRF_FireIntensity",-1];
	private _area = _logic getVariable ["lxRF_FireArea",-1];
	[_logic,"Init",[_intensity,_area]] remoteExecCall ["lxRF_fnc_wildFire"] ;
};

true;