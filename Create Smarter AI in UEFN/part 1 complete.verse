using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Characters }
using { /Fortnite.com/AI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }

# See https://dev.epicgames.com/documentation/en-us/uefn/create-your-own-device-in-verse for how to create a verse device.

# A Verse-authored creative device that can be placed in a level
guard_ai_device := class(creative_device):
    @editable
    GuardSpawner : guard_spawner_device = guard_spawner_device{}

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        GuardSpawner.SpawnedEvent.Subscribe(OnSpawned)
        GuardSpawner.AlertedEvent.Subscribe(OnAlerted)
        GuardSpawner.TargetLostEvent.Subscribe(OnTargetLost)
        GuardSpawner.UnawareEvent.Subscribe(OnUnaware)
        GuardSpawner.EliminatedEvent.Subscribe(OnEliminated)
        GuardSpawner.EliminatingEvent.Subscribe(OnEliminating)

    # Signaled when a guard is spawned.
    # Sends the `agent` guard who was spawned.
    # SpawnedEvent<public>:listenable(agent) = external {}
    OnSpawned(Agent: agent):void=
        if(FC := Agent.GetFortCharacter[], Nav := FC.GetNavigatable[]):
            spawn:
                Roaming(Nav)

    Roaming(Nav: navigatable)<suspends>:void=
        loop:
            X := GetRandomFloat(-5000.0, 5000.0)
            Y := GetRandomFloat(-5000.0, 5000.0)
            Target := MakeNavigationTarget(vector3{X:=X,Y:=Y,Z:=0.0})
            Nav.NavigateTo(Target, ?MovementType:= movement_types.Running, ?ReachRadius:= 0.0)
            
    # Signaled when a guard has identified an opponent.
    # `Source` is the guard who is aware.
    # `Target` is the agent who alerted the guard.
    # AlertedEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnAlerted(Result: device_ai_interaction_result):void=
        if(GuardAgent := Result.Source?, TargetAgent := Result.Target?):
            if(GuardFC := GuardAgent.GetFortCharacter[], GuardFI := GuardFC.GetFocusInterface[]):
                spawn:
                    MaintainFocus(GuardFI, TargetAgent)

    MaintainFocus(GuardFI: focus_interface, TargetAgent: agent)<suspends>:void=
        GuardFI.MaintainFocus(TargetAgent)

    # Signaled when a guard has lost track of a target.
    # `Source` is the guard that lost track of a target.
    # `Target` is the `agent` no longer targeted by the guard.
    # TargetLostEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnTargetLost(Result: device_ai_interaction_result):void=
        ()
                
    # Signaled when a guard becomes unaware.
    # Sends the `agent` guard who is unaware.
    # UnawareEvent<public>:listenable(agent) = external {}
    OnUnaware(Agent: agent):void=
        ()

    # Signaled when a guard is eliminated.
    # `Source` is the `agent` that eliminated the guard. If the guard was eliminated by a non-agent then `Source` is 'false'.
    # `Target` is the guard that was eliminated.
    # EliminatedEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnEliminated(Result: device_ai_interaction_result):void=
        ()

    # Signaled when a guard eliminates an agent.
    # `Source` is the guard that eliminated the agent.
    # `Target` is the agent that was eliminated.
    # EliminatingEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnEliminating(Result: device_ai_interaction_result):void=
        ()
            