using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Characters }
using { /Fortnite.com/AI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }

# See https://dev.epicgames.com/documentation/en-us/uefn/create-your-own-device-in-verse for how to create a verse device.

guard_ai := class:
    Agent: agent
    FC: fort_character
    FI: focus_interface
    Nav: navigatable
    var GuardState : guard_state
    StateChangedEvent : event() = event(){}

    ChangeState(NewGuardState: guard_state):void=
        if(GuardState <> NewGuardState):
            set GuardState = NewGuardState
            StateChangedEvent.Signal()

target := class:
    Agent: agent
    FC: fort_character

guard_state := enum{Roaming, Chasing, Attacking}

# A Verse-authored creative device that can be placed in a level
guard_ai_device := class(creative_device):
    @editable
    GuardSpawner : guard_spawner_device = guard_spawner_device{}
    var OpGuardAi: ?guard_ai = false
    var OpTarget: ?target = false

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
        if(FC := Agent.GetFortCharacter[], Nav := FC.GetNavigatable[], FI := FC.GetFocusInterface[]):
            set OpGuardAi = option{
                guard_ai:
                    Agent := Agent
                    FC := FC
                    FI := FI
                    Nav := Nav                
                    GuardState := guard_state.Roaming
            }
            spawn:
                RunStateMachine()

    RunStateMachine()<suspends>:void=
        if(GuardAi := OpGuardAi?):
            loop:
                if(GuardAi.FC.IsActive[]):
                    race:
                        GuardAi.StateChangedEvent.Await()
                        RunStateOnly(GuardAi)
                else:
                    break

    RunStateOnly(GuardAi: guard_ai)<suspends>:void=
        case (GuardAi.GuardState):
            guard_state.Roaming => Roaming(GuardAi)
            guard_state.Chasing => Chasing(GuardAi)
            guard_state.Attacking => Attacking(GuardAi)

    Roaming(GuardAi: guard_ai)<suspends>:void=
        loop:
            if(GuardAi.FC.IsActive[]):
                X := GetRandomFloat(-5000.0, 5000.0)
                Y := GetRandomFloat(-5000.0, 5000.0)
                Target := MakeNavigationTarget(vector3{X:=X,Y:=Y,Z:=0.0})
                GuardAi.Nav.NavigateTo(Target, ?MovementType:= movement_types.Running, ?ReachRadius:= 0.0)
            else:
                break
            
    Chasing(GuardAi: guard_ai)<suspends>:void=
        if(GuardAi.FC.IsActive[], Target:= OpTarget?, Target.FC.IsActive[]):
            race:
                GuardAi.FI.MaintainFocus(Target.Agent)
                block:
                    NavTarget := MakeNavigationTarget(Target.Agent)
                    GuardAi.Nav.NavigateTo(NavTarget) 

    Attacking(GuardAi: guard_ai)<suspends>:void=
        if(GuardAi.FC.IsActive[], Target:= OpTarget?, Target.FC.IsActive[]):
            race:
                GuardAi.FI.MaintainFocus(Target.Agent)
                MoveZigZagPattern(GuardAi, Target)

    MoveZigZagPattern(GuardAi: guard_ai, Target: target)<suspends>:void=
        loop:
            if(GuardAi.FC.IsActive[]):
                X := GetRandomFloat(-5000.0, 5000.0)
                Y := GetRandomFloat(-5000.0, 5000.0)
                NavTarget := MakeNavigationTarget(vector3{X:=X,Y:=Y,Z:=0.0})
                GuardAi.Nav.NavigateTo(NavTarget, ?MovementType:= movement_types.Running, ?ReachRadius:= 0.0)
            else:
                break

    # Signaled when a guard has identified an opponent.
    # `Source` is the guard who is aware.
    # `Target` is the agent who alerted the guard.
    # AlertedEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnAlerted(Result: device_ai_interaction_result):void=
        if(GuardAgent := Result.Source?, TargetAgent := Result.Target?, TargetFC := TargetAgent.GetFortCharacter[], GuardAi := OpGuardAi?):
            set OpTarget = option{
                target {
                    Agent := TargetAgent,
                    FC := TargetFC
                }
            }
            GuardAi.ChangeState(guard_state.Attacking)

    MaintainFocus(GuardFI: focus_interface, TargetAgent: agent)<suspends>:void=
        GuardFI.MaintainFocus(TargetAgent)

    # Signaled when a guard has lost track of a target.
    # `Source` is the guard that lost track of a target.
    # `Target` is the `agent` no longer targeted by the guard.
    # TargetLostEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnTargetLost(Result: device_ai_interaction_result):void=
        if(GuardAgent := Result.Source?, TargetAgent := Result.Target?, GuardAi := OpGuardAi?):
            if(TargetFC := TargetAgent.GetFortCharacter[]):
                set OpTarget = option{
                    target {
                        Agent := TargetAgent,
                        FC := TargetFC
                    }
                }
                GuardAi.ChangeState(guard_state.Chasing)
            else:
                set OpTarget = false
                GuardAi.ChangeState(guard_state.Roaming)
                
    # Signaled when a guard becomes unaware.
    # Sends the `agent` guard who is unaware.
    # UnawareEvent<public>:listenable(agent) = external {}
    OnUnaware(Agent: agent):void=
        if(GuardAi := OpGuardAi?):
            set OpTarget = false
            GuardAi.ChangeState(guard_state.Roaming)

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
        if(GuardAi := OpGuardAi?):
            set OpTarget = false
            GuardAi.ChangeState(guard_state.Roaming)
            