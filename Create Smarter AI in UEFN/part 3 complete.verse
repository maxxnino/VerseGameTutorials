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
    var OpTarget: ?target = false
    StateChangedEvent : event() = event(){}

    ChangeState(NewGuardState: guard_state):void=
        if(GuardState <> NewGuardState):
            set GuardState = NewGuardState
            StateChangedEvent.Signal()

    OnSpawned():void=
        spawn:
            RunStateMachine()

    RunStateMachine()<suspends>:void=
        loop:
            if(FC.IsActive[]):
                race:
                    StateChangedEvent.Await()
                    RunStateOnly()
            else:
                break

    RunStateOnly()<suspends>:void=
        case (GuardState):
            guard_state.Roaming => Roaming()
            guard_state.Chasing => Chasing()
            guard_state.Attacking => Attacking()

    Roaming()<suspends>:void=
        loop:
            if(FC.IsActive[]):
                X := GetRandomFloat(-5000.0, 5000.0)
                Y := GetRandomFloat(-5000.0, 5000.0)
                Target := MakeNavigationTarget(vector3{X:=X,Y:=Y,Z:=0.0})
                Nav.NavigateTo(Target, ?MovementType:= movement_types.Running, ?ReachRadius:= 0.0)
            else:
                break
            
    Chasing()<suspends>:void=
        if(FC.IsActive[], Target:= OpTarget?):
            if(Target.FC.IsActive[]):
                race:
                    FI.MaintainFocus(Target.Agent)
                    block:
                        NavTarget := MakeNavigationTarget(Target.Agent)
                        Nav.NavigateTo(NavTarget) 
            else:
                ChangeState(guard_state.Roaming)

    Attacking()<suspends>:void=
        if(FC.IsActive[], Target:= OpTarget?):
            if(Target.FC.IsActive[]):
                race:
                    FI.MaintainFocus(Target.Agent)
                    MoveZigZagPattern(Target)
            else:
                ChangeState(guard_state.Roaming)

    MoveZigZagPattern(Target: target)<suspends>:void=
        loop:
            GuardTranslation := FC.GetTransform().Translation
            TargetTranslation := Target.FC.GetTransform().Translation
            Direction :=  TargetTranslation - GuardTranslation
            if:
                FC.IsActive[]
                Target.FC.IsActive[]
                UnitVector := vector3{X:= Direction.X, Y := Direction.Y, Z := 0.0}.MakeUnitVector[]
            then:
                RotateDegrees := GetRandomFloat(-90.0, 90.0)
                RotateRadians := DegreesToRadians(RotateDegrees)
                Rotator := MakeRotation(vector3{X:= 0.0, Y:= 0.0, Z:=1.0}, RotateRadians)
                MoveDistance := GetRandomFloat(768.0, 1024.0)
                MoveDir := Rotator.RotateVector(UnitVector) * vector3{X := MoveDistance, Y := MoveDistance, Z := 0.0}
                Destination := GuardTranslation + MoveDir
                NavTarget := MakeNavigationTarget(Destination)
                MovementSpeed := GetRandomFloat(1.5, 1.7)
                Nav.SetMovementSpeedMultiplier(MovementSpeed)
                Nav.NavigateTo(NavTarget, ?MovementType := movement_types.Running, ?ReachRadius := 400.0)
            else:
                break

    OnAlerted(TargetAgent: agent, TargetFC: fort_character):void=
        set OpTarget = option{
            target {
                Agent := TargetAgent,
                FC := TargetFC
            }
        }
        ChangeState(guard_state.Attacking)

    OnTargetLost(TargetAgent: agent):void=
        if(TargetFC := TargetAgent.GetFortCharacter[]):
            set OpTarget = option{
                target {
                    Agent := TargetAgent,
                    FC := TargetFC
                }
            }
            ChangeState(guard_state.Chasing)
        else:
            set OpTarget = false
            ChangeState(guard_state.Roaming)
                
    OnUnaware():void=
        set OpTarget = false
        ChangeState(guard_state.Roaming)

    OnEliminating():void=
        set OpTarget = false
        ChangeState(guard_state.Roaming)

    OnDamaged(TargetAgent: agent, TargetFC: fort_character):void=
        if(GuardState = guard_state.Roaming):
            set OpTarget = option{
                target {
                    Agent := TargetAgent,
                    FC := TargetFC
                }
            }
            ChangeState(guard_state.Chasing)
    

target := class:
    Agent: agent
    FC: fort_character

guard_state := enum{Roaming, Chasing, Attacking}

# A Verse-authored creative device that can be placed in a level
guard_ai_device:= class<concrete>():
    @editable
    GuardSpawner : guard_spawner_device = guard_spawner_device{}
    var GuardAiMap: [agent]guard_ai = map{}

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        GuardSpawner.SpawnedEvent.Subscribe(OnSpawned)
        GuardSpawner.AlertedEvent.Subscribe(OnAlerted)
        GuardSpawner.TargetLostEvent.Subscribe(OnTargetLost)
        GuardSpawner.UnawareEvent.Subscribe(OnUnaware)
        GuardSpawner.EliminatedEvent.Subscribe(OnEliminated)
        GuardSpawner.EliminatingEvent.Subscribe(OnEliminating)
        GuardSpawner.DamagedEvent.Subscribe(OnDamaged)

    # Signaled when a guard is spawned.
    # Sends the `agent` guard who was spawned.
    # SpawnedEvent<public>:listenable(agent) = external {}
    OnSpawned(Agent: agent):void=
        if(FC := Agent.GetFortCharacter[], Nav := FC.GetNavigatable[], FI := FC.GetFocusInterface[]):
            GuardAi := guard_ai:
                Agent := Agent
                FC := FC
                FI := FI
                Nav := Nav                
                GuardState := guard_state.Roaming
            if(set GuardAiMap[Agent] = GuardAi):
                GuardAi.OnSpawned()

    # Signaled when a guard has identified an opponent.
    # `Source` is the guard who is aware.
    # `Target` is the agent who alerted the guard.
    # AlertedEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnAlerted(Result: device_ai_interaction_result):void=
        if(GuardAgent := Result.Source?, TargetAgent := Result.Target?, TargetFC := TargetAgent.GetFortCharacter[]):
            if(GuardAi := GuardAiMap[GuardAgent]):
                GuardAi.OnAlerted(TargetAgent, TargetFC)

    # Signaled when a guard has lost track of a target.
    # `Source` is the guard that lost track of a target.
    # `Target` is the `agent` no longer targeted by the guard.
    # TargetLostEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnTargetLost(Result: device_ai_interaction_result):void=
        if(GuardAgent := Result.Source?, TargetAgent := Result.Target?):
            if(GuardAi := GuardAiMap[GuardAgent]):
                GuardAi.OnTargetLost(TargetAgent)
                
    # Signaled when a guard becomes unaware.
    # Sends the `agent` guard who is unaware.
    # UnawareEvent<public>:listenable(agent) = external {}
    OnUnaware(Agent: agent):void=
        if(GuardAi := GuardAiMap[Agent]):
            GuardAi.OnUnaware()

    # Signaled when a guard is eliminated.
    # `Source` is the `agent` that eliminated the guard. If the guard was eliminated by a non-agent then `Source` is 'false'.
    # `Target` is the guard that was eliminated.
    # EliminatedEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnEliminated(Result: device_ai_interaction_result):void=
        if(GuardAgent := Result.Target?):
            var NewGuadAiMap: [agent]guard_ai = map{}
            for (Agent -> GuardAi: GuardAiMap, Agent <> GuardAgent):
                set NewGuadAiMap = ConcatenateMaps(NewGuadAiMap, map{Agent => GuardAi})
            set GuardAiMap = NewGuadAiMap

    # Signaled when a guard eliminates an agent.
    # `Source` is the guard that eliminated the agent.
    # `Target` is the agent that was eliminated.
    # EliminatingEvent<public>:listenable(device_ai_interaction_result) = external {}
    OnEliminating(Result: device_ai_interaction_result):void=
        if(GuardAgent := Result.Source?):
            if(GuardAi := GuardAiMap[GuardAgent]):
                GuardAi.OnEliminating()

    # Signaled when guard is damaged.
    # `Source` is the `agent` that damaged the guard. If the guard was damaged by a non-agent then `false` is returned.
    # `Target` is the guard that was damaged.
    OnDamaged(Result: device_ai_interaction_result):void=
        if:
            GuardAgent := Result.Target?
            GuardAi := GuardAiMap[GuardAgent]
            TargetAgent := Result.Source?
            TargetFC := TargetAgent.GetFortCharacter[]
        then:
            GuardAi.OnDamaged(TargetAgent, TargetFC)
