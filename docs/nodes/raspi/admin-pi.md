# admin-pi.fritz.box

```kroki-plantuml
@startuml

skinparam linetype ortho
skinparam backgroundColor transparent
skinparam fontColor #E2E4E9
skinparam arrowColor #E2E4E9
skinparam ArrowFontColor #E2E4E9

skinparam ComponentFontColor #E2E4E9
skinparam ComponentBorderColor #E2E4E9
skinparam ComponentBackgroundColor transparent

skinparam NoteFontColor #E2E4E9
skinparam NoteBorderColor #E2E4E9
skinparam NoteBackgroundColor transparent

skinparam ControlFontColor #E2E4E9
skinparam ControlBorderColor #E2E4E9
skinparam ControlBackgroundColor transparent

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

component api as "admin-pi" <<RasPi 5>> {
    component pihole <<Container>>

    control sdr as "systemd-resolve" <<Linux Service>>
    note bottom of sdr: disabled

    component rest as "every other service"

    sdr -[hidden]right- pihole
    rest -up-> pihole
}

component router as "FritzBox" <<Router>>
router -up-> pihole

control ansible <<Playbook>>

ansible ~down~~> sdr : disable

note right of pihole: DNS for Router and\nevery other service

@enduml
```

## PiHole

!!! warning "Todo"
    Work in progress
