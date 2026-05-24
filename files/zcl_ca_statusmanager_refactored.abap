"====================================================================
" INTERFACES — Dependency Injection
"====================================================================

INTERFACE zif_ca_lock_service.
  METHODS enqueue
    IMPORTING
      iv_status_type TYPE zde_ca_stat_type
      iv_object_key  TYPE zde_ca_stat_obj_key
    RAISING
      zcx_ca_status_error.

  METHODS dequeue
    IMPORTING
      iv_status_type TYPE zde_ca_stat_type
      iv_object_key  TYPE zde_ca_stat_obj_key.
ENDINTERFACE.


INTERFACE zif_ca_number_range_service.
  METHODS get_next_number
    RETURNING
      VALUE(rv_number) TYPE int8
    RAISING
      zcx_ca_status_error.
ENDINTERFACE.


INTERFACE zif_ca_transition_validator.
  METHODS validate
    IMPORTING
      iv_status_type TYPE zde_ca_stat_type
      iv_from_status TYPE zde_ca_stat_code
      iv_to_status   TYPE zde_ca_stat_code
    RAISING
      zcx_ca_status_error.
ENDINTERFACE.


INTERFACE zif_ca_action_resolver.
  METHODS resolve_target_status
    IMPORTING
      iv_status_type TYPE zde_ca_stat_type
      iv_from_status TYPE zde_ca_stat_code
      iv_action_code TYPE char20
    RETURNING
      VALUE(rv_status) TYPE zde_ca_stat_code
    RAISING
      zcx_ca_status_error.
ENDINTERFACE.

"====================================================================
" LOCK SERVICE
"====================================================================

CLASS zcl_ca_lock_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_lock_service.
ENDCLASS.

CLASS zcl_ca_lock_service IMPLEMENTATION.
  METHOD zif_ca_lock_service~enqueue.
    CALL FUNCTION 'ENQUEUE_EZCASTAT_LOCK'
      EXPORTING
        mode_zcastat_log = 'E'
        mandt            = sy-mandt
        status_type      = iv_status_type
        object_key       = iv_object_key
        _scope           = '2'
        _wait            = abap_false
      EXCEPTIONS
        foreign_lock     = 1
        system_failure   = 2
        OTHERS           = 3.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid      = zcx_ca_status_error=>concurrent_lock
          status_type = iv_status_type
          object_key  = iv_object_key
          locked_by   = sy-msgv1.
    ENDIF.
  ENDMETHOD.

  METHOD zif_ca_lock_service~dequeue.
    CALL FUNCTION 'DEQUEUE_EZCASTAT_LOCK'
      EXPORTING
        mode_zcastat_log = 'E'
        mandt            = sy-mandt
        status_type      = iv_status_type
        object_key       = iv_object_key.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" NUMBER RANGE SERVICE
"====================================================================

CLASS zcl_ca_number_range_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_number_range_service.
ENDCLASS.

CLASS zcl_ca_number_range_service IMPLEMENTATION.
  METHOD zif_ca_number_range_service~get_next_number.
    DATA lv_number TYPE num10.
    TRY.
        CALL FUNCTION 'NUMBER_GET_NEXT'
          EXPORTING
            nr_range_nr             = '01'
            object                  = 'ZCASTAT_NR'
          IMPORTING
            number                  = lv_number
          EXCEPTIONS
            number_range_not_intern = 1
            object_not_found        = 2
            quantity_is_0           = 3
            quantity_is_not_1       = 4
            interval_not_found      = 5
            period_not_found        = 6
            blocks_not_found        = 7
            no_object_reference     = 8
            OTHERS                  = 9.

        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_ca_status_error
            EXPORTING
              textid = zcx_ca_status_error=>number_range_error.
        ENDIF.
        rv_number = lv_number.
      CATCH cx_root INTO DATA(lx_root).
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid            = zcx_ca_status_error=>number_range_error
            previous_exception = lx_root.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" TRANSITION VALIDATOR
"====================================================================

CLASS zcl_ca_transition_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_transition_validator.
ENDCLASS.

CLASS zcl_ca_transition_validator IMPLEMENTATION.
  METHOD zif_ca_transition_validator~validate.
    SELECT SINGLE @abap_true
      FROM zcastat_action
      WHERE status_type = @iv_status_type
        AND from_status = @iv_from_status
        AND to_status   = @iv_to_status
        AND is_active   = @abap_true
      INTO @DATA(lv_exists).

    IF lv_exists IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid       = zcx_ca_status_error=>invalid_transition
          status_type  = iv_status_type
          from_status  = iv_from_status
          to_status    = iv_to_status.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" ACTION RESOLVER
"====================================================================

CLASS zcl_ca_action_resolver DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_action_resolver.
ENDCLASS.

CLASS zcl_ca_action_resolver IMPLEMENTATION.
  METHOD zif_ca_action_resolver~resolve_target_status.
    SELECT to_status
      FROM zcastat_action
      WHERE status_type  = @iv_status_type
        AND from_status  = @iv_from_status
        AND action_code  = @iv_action_code
        AND is_active    = @abap_true
      INTO TABLE @DATA(lt_targets).

    CASE lines( lt_targets ).
      WHEN 0.
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid      = zcx_ca_status_error=>no_valid_action
            status_type = iv_status_type
            action_code = iv_action_code.
      WHEN 1.
        rv_status = lt_targets[ 1 ]-to_status.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid      = zcx_ca_status_error=>ambiguous_action
            status_type = iv_status_type
            action_code = iv_action_code.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" STATUS LOG REPOSITORY
"====================================================================

CLASS zcl_ca_status_log_repository DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS write_entry
      IMPORTING
        iv_log_uuid    TYPE sysuuid_16
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
        iv_action_code TYPE char20
        iv_from_status TYPE zde_ca_stat_code
        iv_to_status   TYPE zde_ca_stat_code
        iv_remark      TYPE char255          OPTIONAL
        iv_log_number  TYPE int8
      RAISING
        zcx_ca_status_error.

    METHODS get_current_status
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
      RETURNING
        VALUE(rv_status) TYPE zde_ca_stat_code.

    METHODS get_log
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
      RETURNING
        VALUE(rt_log) TYPE STANDARD TABLE OF zcastat_log.

  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ca_status_log_repository IMPLEMENTATION.
  METHOD write_entry.
    TRY.
        INSERT zcastat_log FROM VALUE #(
          mandt        = sy-mandt
          log_uuid     = iv_log_uuid
          log_number   = iv_log_number
          status_type  = iv_status_type
          object_key   = iv_object_key
          from_status  = iv_from_status
          to_status    = iv_to_status
          action_code  = iv_action_code
          remark       = iv_remark
          changed_by   = sy-uname
          changed_at   = cl_abap_context_info=>get_system_date_time( )
          changed_date = sy-datum
          changed_time = sy-uzeit
        ).
      CATCH cx_root INTO DATA(lx_root).
        RAISE EXCEPTION TYPE zcx_ca_status_error
          EXPORTING
            textid            = zcx_ca_status_error=>log_write_failed
            previous_exception = lx_root.
    ENDTRY.
  ENDMETHOD.

  METHOD get_current_status.
    SELECT SINGLE to_status
      FROM zcastat_log
      WHERE status_type = @iv_status_type
        AND object_key  = @iv_object_key
      ORDER BY log_number DESCENDING
               changed_at DESCENDING
      INTO @rv_status.
  ENDMETHOD.

  METHOD get_log.
    SELECT *
      FROM zcastat_log
      WHERE status_type = @iv_status_type
        AND object_key  = @iv_object_key
      ORDER BY log_number ASCENDING
               changed_at ASCENDING
      INTO TABLE @rt_log.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" TRANSITION BADI HANDLER
"====================================================================

CLASS zcl_ca_transition_badi_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS validate_transition
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
        iv_from_status TYPE zde_ca_stat_code
        iv_to_status   TYPE zde_ca_stat_code
      RAISING
        zcx_ca_status_error.

    METHODS after_transition
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
        iv_from_status TYPE zde_ca_stat_code
        iv_to_status   TYPE zde_ca_stat_code
        iv_log_uuid    TYPE sysuuid_16.

  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ca_transition_badi_handler IMPLEMENTATION.
  METHOD validate_transition.
    DATA lo_badi TYPE REF TO badi_zcastat_transition.

    GET BADI lo_badi
      FILTERS
        status_type = iv_status_type.

    CALL BADI lo_badi->validate_transition
      EXPORTING
        iv_status_type = iv_status_type
        iv_object_key  = iv_object_key
        iv_from_status = iv_from_status
        iv_to_status   = iv_to_status.
  ENDMETHOD.

  METHOD after_transition.
    DATA lo_badi TYPE REF TO badi_zcastat_transition.

    GET BADI lo_badi
      FILTERS
        status_type = iv_status_type.

    TRY.
        CALL BADI lo_badi->after_transition
          EXPORTING
            iv_status_type = iv_status_type
            iv_object_key  = iv_object_key
            iv_from_status = iv_from_status
            iv_to_status   = iv_to_status
            iv_log_uuid    = iv_log_uuid.
      CATCH cx_root INTO DATA(lx_after).
        cl_abap_message_helper=>handle_exception( exception = lx_after ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" MAIN STATUS MANAGER (Orchestrator)
"====================================================================

CLASS zcl_ca_statusmanager DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        io_lock_service        TYPE REF TO zif_ca_lock_service OPTIONAL
        io_number_range_service TYPE REF TO zif_ca_number_range_service OPTIONAL
        io_transition_validator TYPE REF TO zif_ca_transition_validator OPTIONAL
        io_action_resolver      TYPE REF TO zif_ca_action_resolver OPTIONAL.

    METHODS change_status
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
        iv_action_code TYPE char20
        iv_to_status   TYPE zde_ca_stat_code OPTIONAL
        iv_from_status TYPE zde_ca_stat_code OPTIONAL
        iv_remark      TYPE char255          OPTIONAL
      RAISING
        zcx_ca_status_error.

    METHODS get_current_status
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
      RETURNING
        VALUE(rv_status) TYPE zde_ca_stat_code.

    METHODS get_log
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
      RETURNING
        VALUE(rt_log) TYPE STANDARD TABLE OF zcastat_log.

    METHODS get_available_actions
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_from_status TYPE zde_ca_stat_code
      RETURNING
        VALUE(rt_actions) TYPE STANDARD TABLE OF zcastat_action.

    METHODS is_transition_allowed
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
        iv_action_code TYPE char20
        iv_to_status   TYPE zde_ca_stat_code OPTIONAL
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mo_lock_service TYPE REF TO zif_ca_lock_service.
    DATA mo_number_range_service TYPE REF TO zif_ca_number_range_service.
    DATA mo_transition_validator TYPE REF TO zif_ca_transition_validator.
    DATA mo_action_resolver TYPE REF TO zif_ca_action_resolver.
    DATA mo_log_repository TYPE REF TO zcl_ca_status_log_repository.
    DATA mo_badi_handler TYPE REF TO zcl_ca_transition_badi_handler.

    METHODS validate_and_resolve_statuses
      IMPORTING
        iv_status_type TYPE zde_ca_stat_type
        iv_object_key  TYPE zde_ca_stat_obj_key
        iv_action_code TYPE char20
        iv_from_status TYPE zde_ca_stat_code OPTIONAL
        iv_to_status   TYPE zde_ca_stat_code OPTIONAL
      EXPORTING
        ev_from_status TYPE zde_ca_stat_code
        ev_to_status   TYPE zde_ca_stat_code
      RAISING
        zcx_ca_status_error.
ENDCLASS.

CLASS zcl_ca_statusmanager IMPLEMENTATION.
  METHOD constructor.
    mo_lock_service = io_lock_service ?? NEW zcl_ca_lock_service( ).
    mo_number_range_service = io_number_range_service ?? NEW zcl_ca_number_range_service( ).
    mo_transition_validator = io_transition_validator ?? NEW zcl_ca_transition_validator( ).
    mo_action_resolver = io_action_resolver ?? NEW zcl_ca_action_resolver( ).
    mo_log_repository = NEW zcl_ca_status_log_repository( ).
    mo_badi_handler = NEW zcl_ca_transition_badi_handler( ).
  ENDMETHOD.

  METHOD change_status.
    "--------------------------------------------------------------------
    " ① ENQUEUE LOCK
    "--------------------------------------------------------------------
    mo_lock_service->enqueue(
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key ).

    TRY.
        "--------------------------------------------------------------------
        " ② RESOLVE & VALIDATE STATUSES
        "--------------------------------------------------------------------
        me->validate_and_resolve_statuses(
          EXPORTING
            iv_status_type = iv_status_type
            iv_object_key  = iv_object_key
            iv_action_code = iv_action_code
            iv_from_status = iv_from_status
            iv_to_status   = iv_to_status
          IMPORTING
            ev_from_status = DATA(lv_from)
            ev_to_status   = DATA(lv_to) ).

        "--------------------------------------------------------------------
        " ③ BAdI VALIDATE_TRANSITION (blocking)
        "--------------------------------------------------------------------
        mo_badi_handler->validate_transition(
          iv_status_type = iv_status_type
          iv_object_key  = iv_object_key
          iv_from_status = lv_from
          iv_to_status   = lv_to ).

        "--------------------------------------------------------------------
        " ④ WRITE LOG ENTRY
        "--------------------------------------------------------------------
        DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_num) = mo_number_range_service->get_next_number( ).

        mo_log_repository->write_entry(
          iv_log_uuid    = lv_uuid
          iv_status_type = iv_status_type
          iv_object_key  = iv_object_key
          iv_action_code = iv_action_code
          iv_from_status = lv_from
          iv_to_status   = lv_to
          iv_remark      = iv_remark
          iv_log_number  = lv_num ).

        "--------------------------------------------------------------------
        " ⑤ BAdI AFTER_TRANSITION (non-blocking)
        "--------------------------------------------------------------------
        mo_badi_handler->after_transition(
          iv_status_type = iv_status_type
          iv_object_key  = iv_object_key
          iv_from_status = lv_from
          iv_to_status   = lv_to
          iv_log_uuid    = lv_uuid ).

      FINALLY.
        "--------------------------------------------------------------------
        " ⑥ DEQUEUE LOCK (always)
        "--------------------------------------------------------------------
        mo_lock_service->dequeue(
          iv_status_type = iv_status_type
          iv_object_key  = iv_object_key ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_current_status.
    rv_status = mo_log_repository->get_current_status(
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key ).
  ENDMETHOD.

  METHOD get_log.
    rt_log = mo_log_repository->get_log(
      iv_status_type = iv_status_type
      iv_object_key  = iv_object_key ).
  ENDMETHOD.

  METHOD get_available_actions.
    SELECT *
      FROM zcastat_action
      WHERE status_type  = @iv_status_type
        AND from_status  = @iv_from_status
        AND is_active    = @abap_true
      INTO TABLE @rt_actions.
  ENDMETHOD.

  METHOD is_transition_allowed.
    rv_allowed = abap_false.
    TRY.
        me->validate_and_resolve_statuses(
          EXPORTING
            iv_status_type = iv_status_type
            iv_object_key  = iv_object_key
            iv_action_code = iv_action_code
            iv_to_status   = iv_to_status
          IMPORTING
            ev_from_status = DATA(lv_current)
            ev_to_status   = DATA(lv_target) ).

        rv_allowed = abap_true.
      CATCH zcx_ca_status_error.
        rv_allowed = abap_false.
    ENDTRY.
  ENDMETHOD.

  METHOD validate_and_resolve_statuses.
    "--------------------------------------------------------------------
    " Resolve current status (from log or parameter)
    "--------------------------------------------------------------------
    DATA(lv_from) = COND zde_ca_stat_code(
      WHEN iv_from_status IS NOT INITIAL
      THEN iv_from_status
      ELSE mo_log_repository->get_current_status(
             iv_status_type = iv_status_type
             iv_object_key  = iv_object_key )
    ).

    "--------------------------------------------------------------------
    " Resolve target status (from parameter or action resolution)
    "--------------------------------------------------------------------
    DATA(lv_to) = COND zde_ca_stat_code(
      WHEN iv_to_status IS NOT INITIAL
      THEN iv_to_status
      ELSE mo_action_resolver->resolve_target_status(
             iv_status_type = iv_status_type
             iv_from_status = lv_from
             iv_action_code = iv_action_code )
    ).

    "--------------------------------------------------------------------
    " Validate transition config
    "--------------------------------------------------------------------
    mo_transition_validator->validate(
      iv_status_type = iv_status_type
      iv_from_status = lv_from
      iv_to_status   = lv_to ).

    "--------------------------------------------------------------------
    " Export resolved statuses
    "--------------------------------------------------------------------
    ev_from_status = lv_from.
    ev_to_status   = lv_to.
  ENDMETHOD.
ENDCLASS.
