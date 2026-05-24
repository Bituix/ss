# Z-Status Framework — MVP (v12)

Pure ABAP API · No CDS · No RAP · No Fiori  
14 objects · 4 tables · 1 class · 1 interface · 1 exception

---

## Naming conventions (v12)
Domains: `ZDO_CA_*` · Data elements: `ZDE_CA_*`  
Fields: `status_type`, `object_key`, `log_number`, `from_status`, `to_status`, `created_by`, `changed_by`

---

## What is in the MVP (14 objects)

| Category | Objects |
|---|---|
| Domains (3) | ZDO_CA_STAT_TYPE · ZDO_CA_STAT_CODE · ZDO_CA_STAT_OBJ_KEY |
| Data elements (4) | ZDE_CA_STAT_TYPE · ZDE_CA_STAT_CODE · ZDE_CA_STAT_TYPE_DESC · ZDE_CA_STAT_OBJ_KEY |
| Tables (4) | ZCASTAT_TYPE · ZCASTAT_CODE · ZCASTAT_ACTION · ZCASTAT_LOG |
| Exception (1) | ZCX_CA_STATUS_ERROR |
| BAdI interface (1) | ZIFI_CA_STAT_TRANSITION |
| Manager class (1) | ZCL_CA_STATUSMANAGER |

## Deferred to Phase 2

ZCASTAT_LANE · ZCASTAT_FLWNODE · ZCASTAT_FLWCONN · Draft tables · CDS views · BDEFs · ZBP_CA_STATUSTYPE

---

## Activation sequence

1. **abapgit pull** `ZStatusFramework_MVP_v12_abapgit.zip`
2. **SE11** — activate domains then data elements (mass activate)
3. **SE11** — activate tables: ZCASTAT_TYPE → CODE → ACTION → LOG
4. **SE11** — create lock object `EZCASTAT_LOCK`
   - Table: ZCASTAT_LOG · Mode: E
   - Fields: `STATUS_TYPE` (ZDE_CA_STAT_TYPE) + `OBJECT_KEY` (ZDE_CA_STAT_OBJ_KEY)
5. **SNRO** — create number range `ZCASTAT_NR`
   - Interval 01 · 0000000001–9999999999 · Buffered size 10
6. **SE19** — create `ESPOT_ZCASTAT` + `BADI_ZCASTAT_TRANSITION`
   - Filter: `STATUS_TYPE` typed with **ZDE_CA_STAT_TYPE (CHAR 40)**
   - Multiple use: Yes · Default impl: No
7. **SE91** — create message class `ZCASTAT_MSG` with 6 exception texts
8. **ADT/SE24** — activate: `ZCX_CA_STATUS_ERROR` → `ZIFI_CA_STAT_TRANSITION` → `ZCL_CA_STATUSMANAGER`
9. **SE16N** — seed data (see below)

---

## Minimum seed data

**ZCASTAT_TYPE**
```
STATUS_TYPE       = 'ZMM_PO_REQUEST'
STATUS_TYPE_DESC  = 'Purchase Order Request'
IS_ACTIVE         = 'X'
```

**ZCASTAT_CODE**
```
STATUS_TYPE       STATUS_CODE   STATUS_LABEL        CRITICALITY  IS_INITIAL  IS_FINAL
ZMM_PO_REQUEST    SUBM          Submitted           5            X
ZMM_PO_REQUEST    PNDG          Pending Approval    2
ZMM_PO_REQUEST    APPR          Approved            3                        X
ZMM_PO_REQUEST    RJCT          Rejected            1
```

**ZCASTAT_ACTION**
```
STATUS_TYPE       FROM_STATUS   TO_STATUS   ACTION_CODE   ACTION_NAME
ZMM_PO_REQUEST    SUBM          PNDG        SUBMIT        Submit for Approval
ZMM_PO_REQUEST    PNDG          APPR        APPROVE       Approve
ZMM_PO_REQUEST    PNDG          RJCT        REJECT        Reject
```

---

## Usage

```abap
DATA lo_mgr TYPE REF TO zcl_ca_statusmanager.
lo_mgr = NEW #( ).

" Execute a transition
TRY.
  lo_mgr->change_status(
    iv_status_type = 'ZMM_PO_REQUEST'
    iv_object_key  = ls_po-ebeln
    iv_action_code = 'SUBMIT'
    iv_remark      = 'Submitted for approval' ).
  COMMIT WORK AND WAIT.
CATCH zcx_ca_status_error INTO DATA(lx).
  ROLLBACK WORK.
  MESSAGE lx->get_text( ) TYPE 'E'.
ENDTRY.

" Read current status
DATA(lv_status) = lo_mgr->get_current_status(
  iv_status_type = 'ZMM_PO_REQUEST'
  iv_object_key  = ls_po-ebeln ).

" Get actions available from current state
DATA(lt_actions) = lo_mgr->get_available_actions(
  iv_status_type = 'ZMM_PO_REQUEST'
  iv_from_status = lv_status ).

" Check before enabling a button
IF lo_mgr->is_transition_allowed(
     iv_status_type = 'ZMM_PO_REQUEST'
     iv_object_key  = ls_po-ebeln
     iv_action_code = 'APPROVE' ) = abap_true.
  " enable Approve button
ENDIF.
```

---

## Phase 2

Pull `ZStatusFramework_v12_abapgit.zip` — adds ProcessFlow config tables, all CDS views, RAP BDEFs, and the deletion guard behavior implementation. Tables and `ZCL_CA_STATUSMANAGER` are identical — no migration required.
