unit Sample.Androidapi.AppGlue;

{$IF (RTLVersion < 32) }
  {$MESSAGE Error 'This unit should only be used on Delphi 10.2 Tokyo and later.'}
{$ENDIF}

{ Delphi 10.2 Tokyo completely changed the application model on Android. It
  removed a lot of declarations from the Androidapi.AppGlue unit. Since we want
  to be compatible with some older version of Delphi as well, we add those
  older declarations here. }

interface

uses
  Posix.SysTypes,
  Posix.StdLib,
  Posix.Unistd,
  Posix.Pthread,
  Posix.DlfCn,
  Androidapi.Input,
  Androidapi.NativeActivity,
  Androidapi.NativeWindow,
  Androidapi.Rect,
  Androidapi.Configuration,
  Androidapi.Looper;

type
  Pandroid_app = ^Tandroid_app;
  Pandroid_poll_source = ^android_poll_source;

  android_poll_source = record
    // The identifier of this source.  May be LOOPER_ID_MAIN or LOOPER_ID_INPUT.
    id: Int32;
    // The android_app this ident is associated with.
    app: Pandroid_app;
    // Function to call to perform the standard processing of data from this source.
    process: procedure(app: Pandroid_app; source: Pandroid_poll_source); cdecl;
  end;

  TAndroid_app = record
    // The application can place a pointer to its own state object here if it likes.
    userData: Pointer;
    // Fill this in with the function to process main app commands (APP_CMD_*)
    onAppCmd: procedure(App: PAndroid_app; Cmd: Int32); cdecl;
    // Fill this in with the function to process input events.  At this point
    // the event has already been pre-dispatched, and it will be finished upon
    // return. Return if you have handled the event, 0 for any default
    // dispatching.
    onInputEvent: function(App: PAndroid_app; Event: PAInputEvent): Int32; cdecl;
    // The ANativeActivity object instance that this app is running in.
    activity: PANativeActivity;
    // The current configuration the app is running in.
    config: PAConfiguration;
    // This is the last instance's saved state, as provided at creation time.
    // It is NULL if there was no state.  You can use this as you need; the
    // memory will remain around until you call android_app_exec_cmd() for
    // APP_CMD_RESUME, at which point it will be freed and savedState set to NULL.
    // These variables should only be changed when processing a APP_CMD_SAVE_STATE,
    // at which point they will be initialized to NULL and you can malloc your
    // state and place the information here.  In that case the memory will be
    // freed for you later.
    savedState: Pointer;
    savedStateSize: size_t;
    // The ALooper associated with the app's thread.
    looper: PALooper;
    // When non-NULL, this is the input queue from which the app will
    // receive user input events.
    inputQueue: PAInputQueue;
    // When non-NULL, this is the window surface that the app can draw in.
    window: PANativeWindow;
    // Current content rectangle of the window; this is the area where the
    // window's content should be placed to be seen by the user.
    contentRect: ARect;
    // Current state of the app's activity.  May be either APP_CMD_START,
    // APP_CMD_RESUME, APP_CMD_PAUSE, or APP_CMD_STOP; see below.
    activityState: Integer;
    // This is non-zero when the application's NativeActivity is being
    // destroyed and waiting for the app thread to complete.
    destroyRequested: Integer;
    // -------------------------------------------------
    // Below are "private" implementation of the glue code.
    mutex: pthread_mutex_t;
    cond: pthread_cond_t;
    msgread: Integer;
    msgwrite: Integer;
    thread: pthread_t;
    cmdPollSource: android_poll_source;
    inputPollSource: android_poll_source;
    running: Integer;
    stateSaved: Integer;
    destroyed: Integer;
    redrawNeeded: Integer;
    pendingInputQueue: PAInputQueue;
    pendingWindow: PANativeWindow;
    pendingContentRect: ARect;
  end;

const
  { Looper data ID of commands coming from the app's main thread, which
   is returned as an identifier from ALooper_pollOnce().  The data for this
    identifier is a pointer to an android_poll_source structure.
    These can be retrieved and processed with android_app_read_cmd()
    and android_app_exec_cmd().
  }
  LOOPER_ID_MAIN = 1;
  { Looper data ID of events coming from the AInputQueue of the
    application's window, which is returned as an identifier from
    ALooper_pollOnce().  The data for this identifier is a pointer to an
    android_poll_source structure.  These can be read via the inputQueue
    object of android_app.
  }
  LOOPER_ID_INPUT = 2;
  { Start of user-defined ALooper identifiers.
  }
  LOOPER_ID_USER = 3;

const
  { Command from main thread: the AInputQueue has changed.  Upon processing
    this command, android_app->inputQueue will be updated to the new queue
    (or NULL).
  }
  APP_CMD_INPUT_CHANGED = 0;
  { Command from main thread: a new ANativeWindow is ready for use.  Upon
    receiving this command, android_app->window will contain the new window
    surface.
  }
  APP_CMD_INIT_WINDOW = 1;
  { Command from main thread: the existing ANativeWindow needs to be
    terminated.  Upon receiving this command, android_app->window still
    contains the existing window; after calling android_app_exec_cmd
    it will be set to NULL.
  }
  APP_CMD_TERM_WINDOW = 2;
  { Command from main thread: the current ANativeWindow has been resized.
    Please redraw with its new size.
  }
  APP_CMD_WINDOW_RESIZED = 3;
  { Command from main thread: the system needs that the current ANativeWindow
    be redrawn.  You should redraw the window before handing this to
    android_app_exec_cmd() in order to avoid transient drawing glitches.
  }
  APP_CMD_WINDOW_REDRAW_NEEDED = 4;
  { Command from main thread: the content area of the window has changed,
    such as from the soft input window being shown or hidden.  You can
    find the new content rect in android_app::contentRect.
  }
  APP_CMD_CONTENT_RECT_CHANGED = 5;
  { Command from main thread: the app's activity window has gained
    input focus.
  }
  APP_CMD_GAINED_FOCUS = 6;
  { Command from main thread: the app's activity window has lost
    input focus.
  }
  APP_CMD_LOST_FOCUS = 7;
  { Command from main thread: the current device configuration has changed.
  }
  APP_CMD_CONFIG_CHANGED = 8;
  { Command from main thread: the system is running low on memory.
    Try to reduce your memory use.
  }
  APP_CMD_LOW_MEMORY = 9;
  { Command from main thread: the app's activity has been started.
  }
  APP_CMD_START = 10;
  { Command from main thread: the app's activity has been resumed.
  }
  APP_CMD_RESUME = 11;
  { Command from main thread: the app should generate a new saved state
    for itself, to restore from later if needed.  If you have saved state,
    allocate it with malloc and place it in android_app.savedState with
    the size in android_app.savedStateSize.  The will be freed for you
    later.
  }
  APP_CMD_SAVE_STATE = 12;
  { Command from main thread: the app's activity has been paused.
  }
  APP_CMD_PAUSE = 13;
  { Command from main thread: the app's activity has been stopped.
  }
  APP_CMD_STOP = 14;
  { Command from main thread: the app's activity is being destroyed,
    and waiting for the app thread to clean up and exit before proceeding.
  }
  APP_CMD_DESTROY = 15;

procedure app_dummy;

implementation

uses
  Androidapi.Log,
  Androidapi.KeyCodes;

procedure app_dummy;
begin
end;

procedure free_saved_state(android_app: Pandroid_app);
begin
  pthread_mutex_lock(android_app^.mutex);
  if android_app^.savedState <> nil then
  begin
    free(android_app^.savedState);
    android_app^.savedState := nil;
    android_app^.savedStateSize := 0;
  end;
  pthread_mutex_unlock(android_app^.mutex);
end;

function android_app_read_cmd(android_app: Pandroid_app): ShortInt; cdecl;
var
  cmd: ShortInt;
begin
  Result := -1;
  if __read(android_app^.msgread, @cmd, sizeof(cmd)) = SizeOf(cmd) then
  begin
    case cmd of
      APP_CMD_SAVE_STATE:
        free_saved_state(android_app);
    end;
    Result := cmd;
  end
  else
  begin
    LOGW('Error reading command pipe');
    __exit(-1);
  end;
end;

procedure android_app_pre_exec_cmd(android_app: Pandroid_app; cmd: ShortInt); cdecl;
begin
  case cmd of
    APP_CMD_INPUT_CHANGED:
      begin
        pthread_mutex_lock(android_app^.mutex);
        if android_app^.inputQueue <> nil then
          AInputQueue_detachLooper(android_app^.inputQueue);
        android_app^.inputQueue := android_app^.pendingInputQueue;
        if android_app^.inputQueue <> nil then
          AInputQueue_attachLooper(android_app^.inputQueue, android_app^.looper, LOOPER_ID_INPUT, nil,
            @android_app^.inputPollSource);
        pthread_cond_broadcast(android_app^.cond);
        pthread_mutex_unlock(android_app^.mutex);
      end;

    APP_CMD_INIT_WINDOW:
      begin
        pthread_mutex_lock(android_app^.mutex);
        android_app^.window := android_app^.pendingWindow;
        pthread_cond_broadcast(android_app^.cond);
        pthread_mutex_unlock(android_app^.mutex);
      end;

    APP_CMD_TERM_WINDOW:
      pthread_cond_broadcast(android_app^.cond);

    APP_CMD_RESUME, APP_CMD_START, APP_CMD_PAUSE, APP_CMD_STOP:
      begin
        pthread_mutex_lock(android_app^.mutex);
        android_app^.activityState := cmd;
        pthread_cond_broadcast(android_app^.cond);
        pthread_mutex_unlock(android_app^.mutex);
      end;

    APP_CMD_CONFIG_CHANGED:
      AConfiguration_fromAssetManager(android_app^.config, android_app^.activity^.assetManager);

    APP_CMD_DESTROY:
      android_app^.destroyRequested := 1;
  end;
end;

procedure android_app_post_exec_cmd(android_app: Pandroid_app; cmd: ShortInt); cdecl;
begin
  case cmd of
    APP_CMD_TERM_WINDOW:
      begin
        pthread_mutex_lock(android_app^.mutex);
        android_app^.window := nil;
        pthread_cond_broadcast(android_app^.cond);
        pthread_mutex_unlock(android_app^.mutex);
      end;

    APP_CMD_SAVE_STATE:
      begin
        pthread_mutex_lock(android_app^.mutex);
        android_app^.stateSaved := 1;
        pthread_cond_broadcast(android_app^.cond);
        pthread_mutex_unlock(android_app^.mutex);
      end;

    APP_CMD_RESUME:
      { Delphi: It is unclear why this line is necessary in original AppGlue, but it prevents FireMonkey applications
        from recovering saved state. FireMonkey recovers saved state usually after APP_CMD_INIT_WINDOW, which happens
        much later after CMD_RESUME. }
      { free_saved_state(android_app) };
  end;
end;

procedure process_cmd(app: Pandroid_app; source: Pandroid_poll_source); cdecl;
var
  cmd: ShortInt;
begin
  cmd := android_app_read_cmd(app);
  android_app_pre_exec_cmd(app, cmd);
  if Assigned(app^.onAppCmd) then
    app^.onAppCmd(app, cmd);
  android_app_post_exec_cmd(app, cmd);
end;

procedure process_input(app: Pandroid_app; source: Pandroid_poll_source); cdecl;
var
  event: PAInputEvent;
  handled: Int32;
  evType: Int32;
begin
  event := nil;
  while AInputQueue_getEvent(app^.inputQueue, @event) >= 0 do
  begin
    { Delphi: when you press "Back" button to hide virtual keyboard, the keyboard does not disappear but we stop
      receiving events unless the following workaround is placed here.

      This seems to affect Android versions 4.1 and 4.2. }
    evType := AInputEvent_getType(event);
    if ((evType <> AINPUT_EVENT_TYPE_KEY) or (AKeyEvent_getKeyCode(event) <> AKEYCODE_BACK)) then
      if AInputQueue_preDispatchEvent(app^.inputQueue, event) <> 0 then
        Continue;
    handled := 0;
    if Assigned(app^.onInputEvent) then
      handled := app^.onInputEvent(app, event);
    AInputQueue_finishEvent(app^.inputQueue, event, handled);
  end;
end;

procedure android_app_destroy(android_app: Pandroid_app);
begin
  free_saved_state(android_app);
  pthread_mutex_lock(android_app^.mutex);
  if android_app^.inputQueue <> nil then
    AInputQueue_detachLooper(android_app^.inputQueue);
  AConfiguration_delete(android_app^.config);
  android_app^.destroyed := 1;
  pthread_cond_broadcast(android_app^.cond);
  pthread_mutex_unlock(android_app^.mutex);
end;

function android_app_entry(param: Pointer): Pointer; cdecl;

  // Delphi: init system unit and RTL.
  procedure SystemEntry;
  type
    TMainFunction = procedure;
  var
    DlsymPointer: Pointer;
    EntryPoint: TMainFunction;
    Lib: NativeUInt;
    Info: dl_info;
  begin
    if dladdr(NativeUInt(@app_dummy), Info) <> 0 then
    begin
      Lib := dlopen(Info.dli_fname, RTLD_LAZY);
      if Lib <> 0 then
      begin
        DlsymPointer := dlsym(Lib, '_NativeMain');
        dlclose(Lib);
        if DlsymPointer <> nil then
        begin
          EntryPoint := TMainFunction(DlsymPointer);
          EntryPoint;
        end;
      end;
    end;
  end;

var
  android_app: Pandroid_app;
  looper: PALooper;
begin
  android_app := Pandroid_app(param);
  android_app^.config := AConfiguration_new;
  AConfiguration_fromAssetManager(android_app^.config, android_app^.activity^.assetManager);

  android_app^.cmdPollSource.id := LOOPER_ID_MAIN;
  android_app^.cmdPollSource.app := android_app;
  android_app^.cmdPollSource.process := @process_cmd;
  android_app^.inputPollSource.id := LOOPER_ID_INPUT;
  android_app^.inputPollSource.app := android_app;
  android_app^.inputPollSource.process := @process_input;

  looper := ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS);
  ALooper_addFd(looper, android_app^.msgread, LOOPER_ID_MAIN, ALOOPER_EVENT_INPUT, nil, @android_app^.cmdPollSource);
  android_app^.looper := looper;

  pthread_mutex_lock(android_app^.mutex);
  android_app^.running := 1;
  pthread_cond_broadcast(android_app^.cond);
  pthread_mutex_unlock(android_app^.mutex);

  { Delphi: this will initialize System and any RTL related functions, call unit initialization sections and then
    project main code, which will enter application main loop. This call will block until the loop ends, which is
    typically signalled by android_app^.destroyRequested. }
  SystemEntry;

  { This place would be ideal to call unit finalization, class destructors and so on. }
//  Halt;

  android_app_destroy(android_app);

  Result := nil;
end;

function android_app_create(activity: PANativeActivity; savedState: Pointer; savedStateSize: size_t): Pandroid_app;
var
  android_app: Pandroid_app;
  PipeDescriptors: TPipeDescriptors;
  attr: pthread_attr_t;
  thread: pthread_t;
begin
  android_app := Pandroid_app(__malloc(SizeOf(TAndroid_app)));
  FillChar(android_app^, SizeOf(TAndroid_app), 0);
  android_app^.activity := activity;

  pthread_mutex_init(android_app^.mutex, nil);
  pthread_cond_init(android_app^.cond, nil);
  if savedState <> nil then
  begin
    android_app^.savedState := __malloc(savedStateSize);
    android_app^.savedStateSize := savedStateSize;
    Move(PByte(savedState)^, PByte(android_app^.savedState)^, savedStateSize);
  end;

  pipe(PipeDescriptors);
  android_app^.msgread  := PipeDescriptors.ReadDes;
  android_app^.msgwrite := PipeDescriptors.WriteDes;

  pthread_attr_init(attr);
  pthread_attr_setdetachstate(attr, PTHREAD_CREATE_DETACHED);
  pthread_create(thread, attr, @android_app_entry, android_app);

  pthread_mutex_lock(android_app^.mutex);
  while android_app^.running = 0 do
    pthread_cond_wait(android_app^.cond, android_app^.mutex);
  pthread_mutex_unlock(android_app^.mutex);
  Result := android_app;
end;

procedure android_app_write_cmd(android_app: Pandroid_app; cmd: ShortInt);
begin
  if __write(android_app^.msgwrite, @cmd, SizeOf(cmd)) <> SizeOf(cmd) then
    LOGW('Failure writing android_app cmd!');
end;

procedure android_app_free(android_app: Pandroid_app);
begin
  pthread_mutex_lock(android_app^.mutex);
  android_app_write_cmd(android_app, APP_CMD_DESTROY);
  while android_app^.destroyed = 0 do
    pthread_cond_wait(android_app^.cond, android_app^.mutex);
  pthread_mutex_unlock(android_app^.mutex);
  __close(android_app^.msgread);
  __close(android_app^.msgwrite);
  pthread_cond_destroy(android_app^.cond);
  pthread_mutex_destroy(android_app^.mutex);
  __free(android_app);
  System.DelphiActivity := nil;
end;

procedure android_app_set_activity_state(android_app: Pandroid_app; cmd: ShortInt);
begin
  pthread_mutex_lock(android_app^.mutex);
  android_app_write_cmd(android_app, cmd);
  while android_app^.activityState <> cmd do
    pthread_cond_wait(android_app^.cond, android_app^.mutex);
  pthread_mutex_unlock(android_app^.mutex);
end;

procedure android_app_set_window(android_app: Pandroid_app; window: PANativeWindow);
begin
  pthread_mutex_lock(android_app^.mutex);
  if android_app^.pendingWindow <> nil then
    android_app_write_cmd(android_app, APP_CMD_TERM_WINDOW);
  android_app^.pendingWindow := window;
  if window <> nil then
    android_app_write_cmd(android_app, APP_CMD_INIT_WINDOW);
  while android_app^.window <> android_app^.pendingWindow do
    pthread_cond_wait(android_app^.cond, android_app^.mutex);
  pthread_mutex_unlock(android_app^.mutex);
end;

procedure android_app_set_input(android_app: Pandroid_app; inputQueue: PAInputQueue);
begin
  pthread_mutex_lock(android_app^.mutex);
  android_app^.pendingInputQueue := inputQueue;
  android_app_write_cmd(android_app, APP_CMD_INPUT_CHANGED);
  while android_app^.inputQueue <> android_app^.pendingInputQueue do
    pthread_cond_wait(android_app^.cond, android_app^.mutex);
  pthread_mutex_unlock(android_app^.mutex);
end;

procedure onDestroy(activity: PANativeActivity); cdecl;
begin
  android_app_free(Pandroid_app(activity^.instance));
end;

procedure onStart(activity: PANativeActivity); cdecl;
begin
  android_app_set_activity_state(Pandroid_app(activity^.instance), APP_CMD_START);
end;

procedure onResume(activity: PANativeActivity); cdecl;
begin
  android_app_set_activity_state(Pandroid_app(activity^.instance), APP_CMD_RESUME);
end;

function onSaveInstanceState(activity: PANativeActivity; outLen: psize_t): Pointer; cdecl;
var
  android_app: Pandroid_app;
  savedState: Pointer;
begin
  android_app := activity^.instance;
  savedState := nil;

  pthread_mutex_lock(android_app^.mutex);
  android_app^.stateSaved := 0;
  android_app_write_cmd(android_app, APP_CMD_SAVE_STATE);
  while android_app^.stateSaved = 0 do
    pthread_cond_wait(android_app^.cond, android_app^.mutex);
  if android_app^.savedState <> nil then
  begin
    savedState := android_app^.savedState;
    outLen^ := android_app^.savedStateSize;
    android_app^.savedState := nil;
    android_app^.savedStateSize := 0;
  end;
  pthread_mutex_unlock(android_app^.mutex);

  Result := savedState;
end;

procedure onPause(activity: PANativeActivity); cdecl;
begin
  android_app_set_activity_state(Pandroid_app(activity^.instance), APP_CMD_PAUSE);
end;

procedure onStop(activity: PANativeActivity); cdecl;
begin
  android_app_set_activity_state(Pandroid_app(activity^.instance), APP_CMD_STOP);
end;

procedure onConfigurationChanged(activity: PANativeActivity); cdecl;
var
  android_app: Pandroid_app;
begin
  android_app := activity^.instance;
  android_app_write_cmd(android_app, APP_CMD_CONFIG_CHANGED);
end;

procedure onLowMemory(activity: PANativeActivity); cdecl;
var
  android_app: Pandroid_app;
begin
  android_app := activity^.instance;
  android_app_write_cmd(android_app, APP_CMD_LOW_MEMORY);
end;

procedure onWindowFocusChanged(activity: PANativeActivity; focused: Integer); cdecl;
begin
  if focused <> 0 then
    android_app_write_cmd(activity^.instance, APP_CMD_GAINED_FOCUS)
  else
    android_app_write_cmd(activity^.instance, APP_CMD_LOST_FOCUS);
end;

procedure onNativeWindowCreated(activity: PANativeActivity; window: PANativeWindow); cdecl;
begin
  android_app_set_window(activity^.instance, window);
end;

procedure onNativeWindowDestroyed(activity: PANativeActivity; window: PANativeWindow); cdecl;
begin
  android_app_set_window(activity^.instance, nil);
end;

procedure onInputQueueCreated(activity: PANativeActivity; queue: PAInputQueue); cdecl;
begin
  android_app_set_input(activity^.instance, queue);
end;

procedure onInputQueueDestroyed(activity: PANativeActivity; queue: PAInputQueue); cdecl;
begin
  android_app_set_input(activity^.instance, nil);
end;

procedure ANativeActivity_onCreate(activity: PANativeActivity; savedState: Pointer; savedStateSize: size_t); cdecl;
begin
  // According diagram of Android lifecycle activity can change state from OnStop to OnCreate. In this case, we will
  // need to avoid of repeated creation of system resources. Because we release our resource
  // in OnDestroy (last state of Activity).
  if System.DelphiActivity = nil then
  begin
    // Delphi: save Android activity for future use.
    System.DelphiActivity := activity;
    System.JavaMachine := activity^.vm;
    System.JavaContext := activity^.clazz;

    activity^.callbacks^.onDestroy := @onDestroy;
    activity^.callbacks^.onStart := @onStart;
    activity^.callbacks^.onResume := @onResume;
    activity^.callbacks^.onSaveInstanceState := @onSaveInstanceState;
    activity^.callbacks^.onPause := @onPause;
    activity^.callbacks^.onStop := @onStop;
    activity^.callbacks^.onConfigurationChanged := @onConfigurationChanged;
    activity^.callbacks^.onLowMemory := @onLowMemory;
    activity^.callbacks^.onWindowFocusChanged := @onWindowFocusChanged;
    activity^.callbacks^.onNativeWindowCreated := @onNativeWindowCreated;
    activity^.callbacks^.onNativeWindowDestroyed := @onNativeWindowDestroyed;
    activity^.callbacks^.onInputQueueCreated := @onInputQueueCreated;
    activity^.callbacks^.onInputQueueDestroyed := @onInputQueueDestroyed;
    activity^.instance := android_app_create(activity, savedState, savedStateSize);
  end;
end;

exports
  ANativeActivity_onCreate;

end.
