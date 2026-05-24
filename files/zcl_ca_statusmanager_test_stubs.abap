"====================================================================
" TEST STUBS FOR UNIT TESTING
" 
" Usage:
"   DATA(lo_manager) = NEW zcl_ca_statusmanager(
"     io_lock_service = NEW zcl_ca_lock_service_stub( abap_true ) ).
"
"====================================================================

"====================================================================
" LOCK SERVICE STUB
"====================================================================

CLASS zcl_ca_lock_service_stub DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_lock_service.

    METHODS constructor
      IMPORTING
        iv_fail_enqueue TYPE abap_bool DEFAULT abap_false.

    DATA: mv_enqueue_called TYPE abap_bool,
          mv_dequeue_called TYPE abap_bool.

  PRIVATE SECTION.
    DATA: mv_fail_enqueue TYPE abap_bool.
ENDCLASS.

CLASS zcl_ca_lock_service_stub IMPLEMENTATION.
  METHOD constructor.
    mv_fail_enqueue = iv_fail_enqueue.
  ENDMETHOD.

  METHOD zif_ca_lock_service~enqueue.
    mv_enqueue_called = abap_true.
    IF mv_fail_enqueue = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid      = zcx_ca_status_error=>concurrent_lock
          status_type = iv_status_type
          object_key  = iv_object_key
          locked_by   = 'SYSTEM'.
    ENDIF.
  ENDMETHOD.

  METHOD zif_ca_lock_service~dequeue.
    mv_dequeue_called = abap_true.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" NUMBER RANGE SERVICE STUB
"====================================================================

CLASS zcl_ca_number_range_service_stub DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_number_range_service.

    METHODS constructor
      IMPORTING
        iv_fail            TYPE abap_bool DEFAULT abap_false
        iv_start_number    TYPE int8 DEFAULT 1.

    DATA: mv_call_count TYPE int4.

  PRIVATE SECTION.
    DATA: mv_fail TYPE abap_bool,
          mv_next_number TYPE int8.
ENDCLASS.

CLASS zcl_ca_number_range_service_stub IMPLEMENTATION.
  METHOD constructor.
    mv_fail = iv_fail.
    mv_next_number = iv_start_number.
  ENDMETHOD.

  METHOD zif_ca_number_range_service~get_next_number.
    mv_call_count = mv_call_count + 1.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid = zcx_ca_status_error=>number_range_error.
    ENDIF.
    rv_number = mv_next_number.
    mv_next_number = mv_next_number + 1.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" TRANSITION VALIDATOR STUB
"====================================================================

CLASS zcl_ca_transition_validator_stub DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_transition_validator.

    METHODS constructor
      IMPORTING
        iv_is_valid TYPE abap_bool DEFAULT abap_true.

    DATA: mv_validate_called TYPE abap_bool.

  PRIVATE SECTION.
    DATA: mv_is_valid TYPE abap_bool.
ENDCLASS.

CLASS zcl_ca_transition_validator_stub IMPLEMENTATION.
  METHOD constructor.
    mv_is_valid = iv_is_valid.
  ENDMETHOD.

  METHOD zif_ca_transition_validator~validate.
    mv_validate_called = abap_true.
    IF mv_is_valid = abap_false.
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
" ACTION RESOLVER STUB
"====================================================================

CLASS zcl_ca_action_resolver_stub DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_action_resolver.

    METHODS constructor
      IMPORTING
        iv_target_status TYPE zde_ca_stat_code DEFAULT 'APPROVED'
        iv_fail          TYPE abap_bool DEFAULT abap_false.

    DATA: mv_resolve_called TYPE abap_bool.

  PRIVATE SECTION.
    DATA: mv_target_status TYPE zde_ca_stat_code,
          mv_fail TYPE abap_bool.
ENDCLASS.

CLASS zcl_ca_action_resolver_stub IMPLEMENTATION.
  METHOD constructor.
    mv_target_status = iv_target_status.
    mv_fail = iv_fail.
  ENDMETHOD.

  METHOD zif_ca_action_resolver~resolve_target_status.
    mv_resolve_called = abap_true.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_status_error
        EXPORTING
          textid      = zcx_ca_status_error=>no_valid_action
          status_type = iv_status_type
          action_code = iv_action_code.
    ENDIF.
    rv_status = mv_target_status.
  ENDMETHOD.
ENDCLASS.

"====================================================================
" EXAMPLE TEST CLASS
"====================================================================

CLASS ztc_ca_statusmanager DEFINITION
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: mo_manager TYPE REF TO zcl_ca_statusmanager,
          mo_lock_stub TYPE REF TO zcl_ca_lock_service_stub,
          mo_range_stub TYPE REF TO zcl_ca_number_range_service_stub,
          mo_validator_stub TYPE REF TO zcl_ca_transition_validator_stub,
          mo_resolver_stub TYPE REF TO zcl_ca_action_resolver_stub.

    METHODS setup.
    METHODS test_change_status_success FOR TESTING.
    METHODS test_change_status_lock_timeout FOR TESTING.
    METHODS test_change_status_invalid_transition FOR TESTING.
    METHODS test_get_current_status FOR TESTING.
    METHODS test_is_transition_allowed_success FOR TESTING.
    METHODS test_is_transition_allowed_fails FOR TESTING.
ENDCLASS.

CLASS ztc_ca_statusmanager IMPLEMENTATION.
  METHOD setup.
    mo_lock_stub = NEW zcl_ca_lock_service_stub( ).
    mo_range_stub = NEW zcl_ca_number_range_service_stub( ).
    mo_validator_stub = NEW zcl_ca_transition_validator_stub( ).
    mo_resolver_stub = NEW zcl_ca_action_resolver_stub( ).

    mo_manager = NEW zcl_ca_statusmanager(
      io_lock_service         = mo_lock_stub
      io_number_range_service = mo_range_stub
      io_transition_validator = mo_validator_stub
      io_action_resolver      = mo_resolver_stub ).
  ENDMETHOD.

  METHOD test_change_status_success.
    TRY.
        mo_manager->change_status(
          iv_status_type = 'PRRE'
          iv_object_key  = 'DOC001'
          iv_action_code = 'SUBMIT'
          iv_remark      = 'Test' ).

        " Assertions
        cl_abap_unit_assert=>assert_equals(
          act = mo_lock_stub->mv_enqueue_called
          exp = abap_true
          msg = 'Lock enqueue should be called' ).

        cl_abap_unit_assert=>assert_equals(
          act = mo_lock_stub->mv_dequeue_called
          exp = abap_true
          msg = 'Lock dequeue should be called' ).

        cl_abap_unit_assert=>assert_equals(
          act = mo_range_stub->mv_call_count
          exp = 1
          msg = 'Number range should be called once' ).

      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>fail(
          msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_change_status_lock_timeout.
    mo_lock_stub = NEW zcl_ca_lock_service_stub( abap_true ).
    mo_manager = NEW zcl_ca_statusmanager(
      io_lock_service = mo_lock_stub ).

    TRY.
        mo_manager->change_status(
          iv_status_type = 'PRRE'
          iv_object_key  = 'DOC001'
          iv_action_code = 'SUBMIT' ).

        cl_abap_unit_assert=>fail(
          msg = 'Should raise concurrent_lock exception' ).

      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals(
          act = lx->textid
          exp = zcx_ca_status_error=>concurrent_lock
          msg = 'Should be concurrent_lock exception' ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_change_status_invalid_transition.
    mo_validator_stub = NEW zcl_ca_transition_validator_stub( abap_false ).
    mo_manager = NEW zcl_ca_statusmanager(
      io_lock_service         = mo_lock_stub
      io_number_range_service = mo_range_stub
      io_transition_validator = mo_validator_stub
      io_action_resolver      = mo_resolver_stub ).

    TRY.
        mo_manager->change_status(
          iv_status_type = 'PRRE'
          iv_object_key  = 'DOC001'
          iv_action_code = 'INVALID' ).

        cl_abap_unit_assert=>fail(
          msg = 'Should raise invalid_transition exception' ).

      CATCH zcx_ca_status_error INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals(
          act = lx->textid
          exp = zcx_ca_status_error=>invalid_transition
          msg = 'Should be invalid_transition exception' ).

        " Lock dequeue should still be called (FINALLY block)
        cl_abap_unit_assert=>assert_equals(
          act = mo_lock_stub->mv_dequeue_called
          exp = abap_true
          msg = 'Lock dequeue must be called even on error' ).
    ENDTRY.
  ENDMETHOD.

  METHOD test_get_current_status.
    " Note: This would require real data or repo mock
    " Simplified example
    DATA(lv_status) = mo_manager->get_current_status(
      iv_status_type = 'PRRE'
      iv_object_key  = 'DOC001' ).

    " Assert based on setup (e.g., initial state)
    cl_abap_unit_assert=>assert_initial(
      act = lv_status
      msg = 'New object should have initial status' ).
  ENDMETHOD.

  METHOD test_is_transition_allowed_success.
    DATA(lv_allowed) = mo_manager->is_transition_allowed(
      iv_status_type = 'PRRE'
      iv_object_key  = 'DOC001'
      iv_action_code = 'SUBMIT'
      iv_to_status   = 'SUBMITTED' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_allowed
      exp = abap_true
      msg = 'Transition should be allowed with valid config' ).
  ENDMETHOD.

  METHOD test_is_transition_allowed_fails.
    mo_validator_stub = NEW zcl_ca_transition_validator_stub( abap_false ).
    mo_manager = NEW zcl_ca_statusmanager(
      io_lock_service         = mo_lock_stub
      io_number_range_service = mo_range_stub
      io_transition_validator = mo_validator_stub
      io_action_resolver      = mo_resolver_stub ).

    DATA(lv_allowed) = mo_manager->is_transition_allowed(
      iv_status_type = 'PRRE'
      iv_object_key  = 'DOC001'
      iv_action_code = 'INVALID' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_allowed
      exp = abap_false
      msg = 'Transition should not be allowed with invalid config' ).
  ENDMETHOD.
ENDCLASS.
