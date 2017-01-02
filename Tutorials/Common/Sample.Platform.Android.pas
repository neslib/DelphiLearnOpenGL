unit Sample.Platform.Android;

{$INCLUDE 'Sample.inc'}

interface

uses
  Androidapi.Egl,
  Androidapi.AppGlue,
  Androidapi.Input,
  Androidapi.Rect,
  Androidapi.NativeActivity,
  Sample.Platform;

type
  { Implements Android-specific functionality. }
  TPlatformAndroid = class(TPlatformBase)
  {$REGION 'Internal Declarations'}
  private class var
    FAndroidApp: Pandroid_app;
    FDisplay: EGLDisplay;
    FSurface: EGLSurface;
    FContext: EGLContext;
    FConfig: EGLConfig;
    FWidth: Integer;
    FHeight: Integer;
    FInvScreenScale: Single;
  private
    class procedure Setup; static;
    class procedure SetupScreenScale; static;
    class procedure SetupInput; static;
    class procedure RunLoop; static;
    class procedure Shutdown; static;
  private
    class procedure CreateContext; static;
  private
    class procedure HandleAppCmd(var App: TAndroid_app; Cmd: Int32); cdecl; static;
    class function HandleInputEvent(var App: TAndroid_app;
      Event: PAInputEvent): Int32; cdecl; static;
    class procedure HandleContentRectChanged(Activity: PANativeActivity;
      Rect: PARect); cdecl; static;
  {$ENDREGION 'Internal Declarations'}
  protected
    class procedure DoRun; override;
  end;

implementation

uses
  System.Classes,
  System.UITypes,
  System.SysUtils,
  Androidapi.Helpers,
  Androidapi.Looper,
  Androidapi.NativeWindow,
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.Util;

const
  { Missing Delphi declarations }
  AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT = 8;
  AMOTION_EVENT_ACTION_POINTER_INDEX_MASK  = $ff00;

  { As long as this window is visible to the user, keep the device's screen
    turned on and bright. }
  AWINDOW_FLAG_KEEP_SCREEN_ON = $00000080;

  { Hide all screen decorations (such as the status bar) while this window is
    displayed. This allows the window to use the entire display space for
    itself – the status bar will be hidden when an app window with this flag set
    is on the top layer. A fullscreen window will ignore a value of
    AWINDOW_SOFT_INPUT_ADJUST_RESIZE; the window will stay fullscreen and will
    not resize. }
  AWINDOW_FLAG_FULLSCREEN     = $00000400;

{ TPlatformAndroid }

class procedure TPlatformAndroid.CreateContext;
const
  SURFACE_ATTRIBS: array [0..0] of EGLint = (
    EGL_NONE);
  CONTEXT_ATTRIBS: array [0..2] of EGLint = (
    EGL_CONTEXT_CLIENT_VERSION, 2, // OpenGL-ES 2
    EGL_NONE);
var
  NumConfigs, Format: EGLint;
  ConfigAttribs: TArray<EGLint>;
begin
  { TODO: Handle context loss? }

  FDisplay := eglGetDisplay(EGL_DEFAULT_DISPLAY);
  if (FDisplay = EGL_NO_DISPLAY) then
    raise Exception.Create('Unable to get default EGL display');

  if (eglInitialize(FDisplay, nil, nil) = EGL_FALSE) then
    raise Exception.Create('Unable to initialize EGL');

  ConfigAttribs := TArray<EGLint>.Create(
    EGL_RED_SIZE, 8,
    EGL_GREEN_SIZE, 8,
    EGL_BLUE_SIZE, 8,
    EGL_ALPHA_SIZE, 8,
    EGL_DEPTH_SIZE, 16);

  if (TPlatformAndroid.App.NeedStencilBuffer) then
    ConfigAttribs := ConfigAttribs + [EGL_STENCIL_SIZE, 8];

  ConfigAttribs := ConfigAttribs + [
    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
    EGL_NONE];

  if (eglChooseConfig(FDisplay, @ConfigAttribs[0], @FConfig, 1, @NumConfigs) = EGL_FALSE) then
    raise Exception.Create('Unable to create EGL configuration');

  eglGetConfigAttrib(FDisplay, FConfig, EGL_NATIVE_VISUAL_ID, @Format);
  ANativeWindow_setBuffersGeometry(FAndroidApp.window, 0, 0, Format);

  FSurface := eglCreateWindowSurface(FDisplay, FConfig, FAndroidApp.window, @SURFACE_ATTRIBS[0]);
  if (FSurface = EGL_NO_SURFACE) then
    raise Exception.Create('Unable to get create EGL window surface');

  FContext := eglCreateContext(FDisplay, FConfig, EGL_NO_CONTEXT, @CONTEXT_ATTRIBS[0]);
  if (FContext = EGL_NO_CONTEXT) then
    raise Exception.Create('Unable to get create EGL context');

  eglMakeCurrent(FDisplay, FSurface, FSurface, FContext);
end;

class procedure TPlatformAndroid.DoRun;
begin
  { Although calling this routine is not really necessary, but it is a way
    to ensure that "Androidapi.AppGlue.pas" is kept in uses list, in order to
    export ANativeActivity_onCreate callback. }
  app_dummy;

  Setup;
  SetupScreenScale;
  SetupInput;
  RunLoop;
  App.Shutdown;
  Shutdown;
end;

class procedure TPlatformAndroid.HandleAppCmd(var App: TAndroid_app;
  Cmd: Int32);
begin
  { This method gets called for Android NDK commands.
    For commands we are interested in, we convert these to cross-platform
    events. }
  case Cmd of
    APP_CMD_INIT_WINDOW:
      begin
        CreateContext;
        FWidth := ANativeWindow_getWidth(App.window);
        FHeight := ANativeWindow_getHeight(App.window);
        TPlatformAndroid.App.Initialize;
        TPlatformAndroid.App.Resize(FWidth, FHeight);
      end;

    APP_CMD_GAINED_FOCUS:
      { TODO };

    APP_CMD_LOST_FOCUS:
      { TODO };

    APP_CMD_RESUME:
      { TODO };

    APP_CMD_PAUSE:
      { TODO };

    APP_CMD_DESTROY:
      FAndroidApp.destroyRequested := 1;
  end;
end;

class procedure TPlatformAndroid.HandleContentRectChanged(
  Activity: PANativeActivity; Rect: PARect);
var
  Width, Height: Integer;
begin
  { Is called by the native activity when the content bounds have changed,
    usually as a result of the user rotating the device. }
  Width := Rect.right - Rect.left;
  Height := Rect.bottom - Rect.top;
  if (Width <> FWidth) or (Height <> FHeight) then
  begin
    { Resize the render surface to match the new dimensions }
    FWidth := Width;
    FHeight := Height;
    TPlatformAndroid.App.Resize(FWidth, FHeight);
  end;
end;

class function TPlatformAndroid.HandleInputEvent(var App: TAndroid_app;
  Event: PAInputEvent): Int32;
var
  Kind, Source, ActionBits, Count, Action, Index: Integer;
  X, Y: Single;
  Shift: TShiftState;
begin
  { This method gets called for Android NDK input events.
    For events we are interested in, we convert these to cross-platform
    events }
  Kind := AInputEvent_getType(Event);
  Source := AInputEvent_getSource(Event);
  ActionBits := AMotionEvent_getAction(Event);

  case Kind of
    AINPUT_EVENT_TYPE_MOTION:
      begin
        if (Source = AINPUT_SOURCE_TOUCHSCREEN) then
          Shift := [ssTouch]
        else if (Source = AINPUT_SOURCE_MOUSE) then
          Shift := []
        else
          Exit(0);

        X := AMotionEvent_getX(Event, 0) * FInvScreenScale;
        Y := AMotionEvent_getY(Event, 0) * FInvScreenScale;
        Count := AMotionEvent_getPointerCount(Event);

        Action := ActionBits and AMOTION_EVENT_ACTION_MASK;
        Index := (ActionBits and AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) shr AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT;

        if (Count < 2) then
        begin
          { Simulate left mouse click with 1st touch and right mouse click
            with 2nd touch. Ignore other touches. }
          case Action of
            AMOTION_EVENT_ACTION_DOWN:
              TPlatformAndroid.App.MouseDown(TMouseButton.mbLeft, Shift, X, Y);

            AMOTION_EVENT_ACTION_POINTER_DOWN:
              TPlatformAndroid.App.MouseDown(TMouseButton.mbRight, Shift, X, Y);

            AMOTION_EVENT_ACTION_UP:
              TPlatformAndroid.App.MouseUp(TMouseButton.mbLeft, Shift, X, Y);

            AMOTION_EVENT_ACTION_POINTER_UP:
              TPlatformAndroid.App.MouseUp(TMouseButton.mbRight, Shift, X, Y);
          end;
        end;

        case Action of
          AMOTION_EVENT_ACTION_MOVE:
            if (Index = 0) then
              TPlatformAndroid.App.MouseMove(Shift, X, Y);
        end;
      end;
  end;
  Result := 0;
end;

class procedure TPlatformAndroid.RunLoop;
var
  NumEvents: Integer;
  Source: Pandroid_poll_source;
begin
  { Run the Android looper and handle its events. }
  StartClock;
  while (FAndroidApp.destroyRequested = 0) do
  begin
    while (FAndroidApp.destroyRequested = 0) do
    begin
      ALooper_pollAll(0, nil, @NumEvents, @Source);
      if (Source = nil) then
        Break;

      { This can call the HandleAppCmd and HandleInputEvent methods }
      Source.process(FAndroidApp, Source);
    end;

    if (FAndroidApp.destroyRequested = 0) and (FContext <> EGL_NO_CONTEXT) then
    begin
      { Update app and render frame to back buffer }
      Update;

      { Swap backbuffer to front to display it }
      eglSwapBuffers(FDisplay, FSurface);
    end;
  end;
end;

class procedure TPlatformAndroid.Setup;
var
  Activity: PANativeActivity;
begin
  Activity := DelphiActivity;

  { Intercept the onAppCmd and onInputEvent methods of the Android app and
    forward them to our implementations }
  FAndroidApp := Activity.instance;
  FAndroidApp.onAppCmd := @HandleAppCmd;
  FAndroidApp.onInputEvent := @HandleInputEvent;

  { Intercept the onContentRectChanged callback from the Android native activity
    and forward it to our implementation }
  Activity.callbacks.onContentRectChanged := @HandleContentRectChanged;

  { Set the behavior of the main window }
  ANativeActivity_setWindowFlags(Activity, AWINDOW_FLAG_FULLSCREEN or AWINDOW_FLAG_KEEP_SCREEN_ON, 0);
end;

class procedure TPlatformAndroid.SetupInput;
begin
  { TODO }
end;

class procedure TPlatformAndroid.SetupScreenScale;
var
  Metrics: JDisplayMetrics;
begin
  Metrics := TAndroidHelper.DisplayMetrics;
  if Assigned(Metrics) then
    TPlatformAndroid.ScreenScale := Metrics.density;
  FInvScreenScale := 1 / TPlatformAndroid.ScreenScale;
end;

class procedure TPlatformAndroid.Shutdown;
begin
  if (FContext <> EGL_NO_CONTEXT) then
  begin
    eglMakeCurrent(FDisplay, FSurface, FSurface, FContext);
    eglDestroyContext(FDisplay, FContext);
    FContext := EGL_NO_CONTEXT;
  end;

  if (FSurface <> EGL_NO_SURFACE) then
  begin
    eglMakeCurrent(FDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroySurface(FDisplay, FSurface);
    FSurface := EGL_NO_SURFACE;
  end;

  if (FDisplay <> EGL_NO_DISPLAY) then
  begin
    eglTerminate(FDisplay);
    FDisplay := EGL_NO_DISPLAY;
  end;
end;

end.
