# Overview

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

component kobol <<Workstation>>
component caprica <<Workstation>>

component api as "admin-pi" <<Raspi 5>>

component talos as "Talos Cluster" <<Raspi>>

control router
control repeater
control switch

router -down-> repeater
repeater -down-> switch

kobol -right-> router
caprica -down-> router
api -left-> router

talos -> switch

@enduml
```
