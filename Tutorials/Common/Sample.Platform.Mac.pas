unit Sample.Platform.Mac;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  Macapi.ObjectiveC,
  Macapi.CocoaTypes,
  Macapi.Foundation,
  Macapi.AppKit,
  Sample.Platform;

type
  { Implements the macOS NSApplicationDelegate protocol to get notified of
    certain application events. }
  TApplicationDelegate = class(TOCLocal, NSApplicationDelegate)
  public
    { NSApplicationDelegate }

    { Gets called when macOS requests to terminate the app. In this event, we
      set our Terminated flag to True to break out of the run loop so the app
      will terminated. We return NSTerminateCancel to prevent macOS from
      terminating the app, because we want to cleanup before we terminate
      manually. }
    function applicationShouldTerminate(Notification: NSNotification): NSInteger; cdecl;

    { Gets called when the app is about to terminate.
      We don't care about this notification. }
    procedure applicationWillTerminate(Notification: NSNotification); cdecl;

    { Gets called when the app just started.
      We don't care about this notification. }
    procedure applicationDidFinishLaunching(Notification: NSNotification); cdecl;

    { Allows the delegate to supply a dock menu for the application dynamically.
      We don't need this. }
    function applicationDockMenu(sender: NSApplication): NSMenu; cdecl;
  end;

type
  { Implements the macOS NSWindowDelegate protocol to get notified of certain
    window events. We don't care about most of these events, so must methods
    are empty. }
  TWindowDelegate = class(TOCLocal, NSWindowDelegate)
  private
    FWindow: NSWindow;
  public
    { NSWindowDelegate }

    { Is called when the user attemts to close the window. We terminate the
      app in here and return False so macOS doesn't close it for us. }
    function windowShouldClose(Sender: Pointer {id}): Boolean; cdecl;

    procedure windowWillClose(notification: NSNotification); cdecl;

    { Is called when the window receives focus.
      We use this to post Resume events to our event queue. }
    procedure windowDidBecomeKey(notification: NSNotification); cdecl;

    { Is called when the window loses focus.
      We use this to post Suspend events to our event queue. }
    procedure windowDidResignKey(notification: NSNotification); cdecl;

    { Is called when the window is resized.
      We use this to resize the render surface. }
    procedure windowDidResize(notification: NSNotification); cdecl;

    procedure windowDidMove(notification: NSNotification); cdecl;
    procedure windowDidMiniaturize(notification: NSNotification); cdecl;
    procedure windowDidDeminiaturize(notification: NSNotification); cdecl;
    procedure windowDidEnterFullScreen(notification: NSNotification); cdecl;
    procedure windowDidExitFullScreen(notification: NSNotification); cdecl;
    procedure windowDidChangeBackingProperties(notification: NSNotification); cdecl; // OS X 10.7+
  public
    constructor Create(const AWindow: NSWindow);
  end;

type
  { Implements macOS-specific functionality. }
  TPlatformMac = class(TPlatformBase)
  {$REGION 'Internal Declarations'}
  private class var
    FApplication: NSApplication;
    FAppDelegate: NSApplicationDelegate;
    FAppDelegateObj: TApplicationDelegate;
    FMenuBar: NSMenu;
    FWindow: NSWindow;
    FWindowDelegate: NSWindowDelegate;
    FView: NSOpenGLView;
    FContext: NSOpenGLContext;
    FPixelFormat: NSOpenGLPixelFormat;
    FContentRect: NSRect;
    FDistantPast: NSDate;
    FDefaultRunLoopMode: NSString;
    FKeyMapping: array [0..255] of Byte;
    FMouseX: Single;
    FMouseY: Single;
  private
    class procedure SetupApp; static;
    class procedure SetupMenu; static;
    class procedure SetupWindow; static;
    class procedure SetupView; static;
    class procedure SetupOpenGLContext; static;
    class procedure SetupKeyTranslations; static;
    class procedure RunLoop; static;
    class procedure Shutdown; static;
  private
    class function PeekEvent: NSEvent; inline; static;
    class function DispatchEvent(const AEvent: NSEvent): Boolean; static;
    class function HandleKeyEvent(const AEvent: NSEvent): Boolean; static;
    class function GetShiftState(const AFlags: Cardinal): TShiftState; static;
    class procedure GetMousePos; static;
  {$ENDREGION 'Internal Declarations'}
  protected
    class procedure DoRun; override;
  end;

implementation

uses
  System.UITypes,
  System.SysUtils,
  System.Math,
  Macapi.ObjCRuntime,
  Macapi.Helpers,
  Macapi.OpenGL,
  Sample.Classes;

{ TPlatformMac }

class function TPlatformMac.DispatchEvent(const AEvent: NSEvent): Boolean;
begin
  if (AEvent = nil) then
    Exit(False);

  { This method gets called for each macOS message.
    For messages we are interested in, we convert these to cross-platform
    events. }
  case AEvent.&type of
    NSKeyDown,
    NSKeyUp:
      if (HandleKeyEvent(AEvent)) then
        { Returning False means that we take care of the key (instead of the
          default behavior) }
        Exit(False);

    NSMouseMoved,
    NSLeftMouseDragged,
    NSRightMouseDragged,
    NSOtherMouseDragged:
      begin
        GetMousePos;
        TPlatformMac.App.MouseMove(GetShiftState(AEvent.modifierFlags), FMouseX, FMouseY);
      end;

    NSLeftMouseDown:
      TPlatformMac.App.MouseDown(TMouseButton.mbLeft, GetShiftState(AEvent.modifierFlags), FMouseX, FMouseY);

    NSLeftMouseUp:
      TPlatformMac.App.MouseUp(TMouseButton.mbLeft, GetShiftState(AEvent.modifierFlags), FMouseX, FMouseY);

    NSRightMouseDown:
      TPlatformMac.App.MouseDown(TMouseButton.mbRight, GetShiftState(AEvent.modifierFlags), FMouseX, FMouseY);

    NSRightMouseUp:
      TPlatformMac.App.MouseUp(TMouseButton.mbRight, GetShiftState(AEvent.modifierFlags), FMouseX, FMouseY);

    NSOtherMouseDown:
      TPlatformMac.App.MouseDown(TMouseButton.mbMiddle, GetShiftState(AEvent.modifierFlags), FMouseX, FMouseY);

    NSOtherMouseUp:
      TPlatformMac.App.MouseUp(TMouseButton.mbMiddle, GetShiftState(AEvent.modifierFlags), FMouseX, FMouseY);

    NSScrollWheel:
      TPlatformMac.App.MouseWheel(GetShiftState(AEvent.modifierFlags), Trunc(AEvent.deltaY));
  end;

  FApplication.sendEvent(AEvent);
  FApplication.updateWindows;
  Result := True;
end;

class procedure TPlatformMac.DoRun;
begin
  SetupApp;
  SetupMenu;
  SetupWindow;
  SetupView;
  SetupOpenGLContext;
  SetupKeyTranslations;
  App.Initialize;
  RunLoop;
  App.Shutdown;
  Shutdown;
end;

class procedure TPlatformMac.GetMousePos;
var
  Location: NSPoint;
  X, Y: Single;
begin
  Location := FWindow.mouseLocationOutsideOfEventStream;
  X := Location.x;
  Y := FContentRect.size.height - Location.y;

  FMouseX := EnsureRange(X, 0, FContentRect.size.width);
  FMouseY := EnsureRange(Y, 0, FContentRect.size.height);
end;

class function TPlatformMac.GetShiftState(const AFlags: Cardinal): TShiftState;
begin
  { Converts macOS event modifier flags to TShiftState set. }
  Result := [];

  if ((AFlags and NSShiftKeyMask) <> 0) then
    Include(Result, ssShift);

  if ((AFlags and NSAlternateKeyMask) <> 0) then
    Include(Result, ssAlt);

  if ((AFlags and NSControlKeyMask) <> 0) then
    Include(Result, ssCtrl);

  if ((AFlags and NSCommandKeyMask) <> 0) then
    Include(Result, ssCommand);
end;

class function TPlatformMac.HandleKeyEvent(const AEvent: NSEvent): Boolean;
var
  Chars: NSString;
  KeyCode, Key: Integer;
  Shift: TShiftState;
begin
  Chars := AEvent.charactersIgnoringModifiers;
  if (Chars.length = 0) then
    Exit(False);

  KeyCode := Chars.characterAtIndex(0);
  Shift := GetShiftState(AEvent.modifierFlags);

  if (KeyCode < 256) then
    Key := FKeyMapping[KeyCode]
  else case KeyCode of
    NSF1FunctionKey         : Key := vkF1;
    NSF2FunctionKey         : Key := vkF2;
    NSF3FunctionKey         : Key := vkF3;
    NSF4FunctionKey         : Key := vkF4;
    NSF5FunctionKey         : Key := vkF5;
    NSF6FunctionKey         : Key := vkF6;
    NSF7FunctionKey         : Key := vkF7;
    NSF8FunctionKey         : Key := vkF8;
    NSF9FunctionKey         : Key := vkF9;
    NSF10FunctionKey        : Key := vkF10;
    NSF11FunctionKey        : Key := vkF11;
    NSF12FunctionKey        : Key := vkF12;

    NSLeftArrowFunctionKey  : Key := vkLeft;
    NSRightArrowFunctionKey : Key := vkRight;
    NSUpArrowFunctionKey    : Key := vkUp;
    NSDownArrowFunctionKey  : Key := vkDown;

    NSPageUpFunctionKey     : Key := vkPrior;
    NSPageDownFunctionKey   : Key := vkNext;
    NSHomeFunctionKey       : Key := vkHome;
    NSEndFunctionKey        : Key := vkEnd;
    NSPrintScreenFunctionKey: Key := vkPrint;
  else
    Exit(False);
  end;

  if (AEvent.&type = NSKeyDown) then
    App.KeyDown(Key, Shift)
  else
    App.KeyUp(Key, Shift);

  Result := True;
end;

class function TPlatformMac.PeekEvent: NSEvent;
begin
  { Check the macOS event queue for an event that needs to be handled. }
  Result := FApplication.nextEventMatchingMask(NSAnyEventMask, FDistantPast, FDefaultRunLoopMode, True);
end;

class procedure TPlatformMac.RunLoop;
begin
  { Run the macOS run loop }
  StartClock;
  while (not Terminated) do
  begin
    while DispatchEvent(PeekEvent()) do ;

    { Update app and render frame to back buffer }
    Update;

    { Swap backbuffer to front to display it }
    FContext.flushBuffer;
  end;
end;

class procedure TPlatformMac.SetupApp;
begin
  { Cache some commonly used macOS object, so we don't have to load/create them
    every time }
  FDistantPast := TNSDate.Wrap(TNSDate.OCClass.distantPast);
  FDefaultRunLoopMode := NSDefaultRunLoopMode;

  { Create our main NSApplication object and attach or TApplicationDelegate to
    it to get notified of app events. }
  FApplication := TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication);
  FAppDelegateObj := TApplicationDelegate.Create;
  FAppDelegate := FAppDelegateObj;

  FApplication.setDelegate(FAppDelegate);
  FApplication.setActivationPolicy(NSApplicationActivationPolicyRegular);

  { Start the app }
  FApplication.activateIgnoringOtherApps(True);
  FApplication.finishLaunching;
end;

class procedure TPlatformMac.SetupKeyTranslations;
var
  C: Char;
  Key: Byte;
begin
  FillChar(FKeyMapping, SizeOf(FKeyMapping), 0);
  FKeyMapping[27]        := vkEscape;
  FKeyMapping[10]        := vkReturn;
  FKeyMapping[9]         := vkTab;
  FKeyMapping[127]       := vkBack;
  FKeyMapping[Ord(' ')]  := vkSpace;

  FKeyMapping[Ord('+')]  := vkAdd;
  FKeyMapping[Ord('=')]  := vkEqual;
  FKeyMapping[Ord('_')]  := vkSubtract;
  FKeyMapping[Ord('-')]  := vkSubtract;

  FKeyMapping[Ord('~')]  := vkTilde;
  FKeyMapping[Ord('`')]  := vkTilde;

  FKeyMapping[Ord(':')]  := vkSemicolon;
  FKeyMapping[Ord(';')]  := vkSemicolon;
  FKeyMapping[Ord('"')]  := vkQuote;
  FKeyMapping[Ord('''')] := vkQuote;

  FKeyMapping[Ord('{')]  := vkLeftBracket;
  FKeyMapping[Ord('[')]  := vkLeftBracket;
  FKeyMapping[Ord('}')]  := vkRightBracket;
  FKeyMapping[Ord(']')]  := vkRightBracket;

  FKeyMapping[Ord('<')]  := vkComma;
  FKeyMapping[Ord(',')]  := vkComma;
  FKeyMapping[Ord('>')]  := vkPeriod;
  FKeyMapping[Ord('.')]  := vkPeriod;
  FKeyMapping[Ord('?')]  := vkSlash;
  FKeyMapping[Ord('/')]  := vkSlash;
  FKeyMapping[Ord('|')]  := vkBackslash;
  FKeyMapping[Ord('\')]  := vkBackslash;

  for C := '0' to '9' do
    FKeyMapping[Ord(C)]  := vk0 + (Ord(C) - Ord('0'));

  for C := 'a' to 'z' do
  begin
    Key := vkA + Ord(C) - Ord('a');
    FKeyMapping[Ord(C)]       := Key;
    FKeyMapping[Ord(C) - 32]  := Key;
  end;
end;

class procedure TPlatformMac.SetupMenu;
var
  QuitMenuItem, AppMenuItem: NSMenuItem;
  AppMenu: NSMenu;
begin
  { Add a simple menu with just a "Quit" menu option to terminate the app.
    When the user selects the option, it calls the NSApplication.terminate:
    method }
  QuitMenuItem := TNSMenuItem.Wrap(TNSMenuItem.Alloc.initWithTitle(
    StrToNSStr('Quit'), sel_getUid('terminate:'), StrToNSStr('q')));

  AppMenu := TNSMenu.Create;
  AppMenu.addItem(QuitMenuItem);

  AppMenuItem := TNSMenuItem.Create;
  AppMenuItem.setSubmenu(AppMenu);

  FMenuBar := TNSMenu.Create;
  FMenuBar.addItem(AppMenuItem);
  FApplication.setMainMenu(FMenuBar);
end;

class procedure TPlatformMac.SetupOpenGLContext;
var
  Module: HMODULE;
  Attributes: TArray<NSOpenGLPixelFormatAttribute>;
begin
  Attributes := TArray<NSOpenGLPixelFormatAttribute>.Create(
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFADepthSize, 16);

  if (TPlatformMac.App.NeedStencilBuffer) then
    Attributes := Attributes + [NSOpenGLPFAStencilSize, 8];
  Attributes := Attributes + [0];

  FPixelFormat := TNSOpenGLPixelFormat.Wrap(TNSOpenGLPixelFormat.Alloc.initWithAttributes(@Attributes[0]));
  FContext := TNSOpenGLContext.Wrap(TNSOpenGLContext.Alloc.initWithFormat(FPixelFormat, nil));
  FView.setOpenGLContext(FContext);
  FContext.makeCurrentContext;
  Module := InitOpenGL;
  @glGenerateMipmap := GetProcAddress(Module, 'glGenerateMipmap');
end;

class procedure TPlatformMac.SetupView;
var
  ContentView: NSView;
  R: NSRect;
begin
  R.origin.x := 0;
  R.origin.y := 0;
  R.size.width := FContentRect.size.width;
  R.size.height := FContentRect.size.height;
  FView := TNSOpenGLView.Wrap(TNSOpenGLView.Alloc.initWithFrame(R, TNSOpenGLView.OCClass.defaultPixelFormat));
  if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_7) then
    FView.setWantsBestResolutionOpenGLSurface(True);

  FView.setAutoresizingMask(NSViewWidthSizable or NSViewHeightSizable);
  ContentView := TNSView.Wrap(FWindow.contentView);
  ContentView.setAutoresizesSubviews(True);
  ContentView.addSubview(FView);
end;

class procedure TPlatformMac.SetupWindow;
const
  WINDOW_STYLE = NSTitledWindowMask or NSClosableWindowMask
    or NSMiniaturizableWindowMask or NSResizableWindowMask;
var
  Screen: NSScreen;
  ScreenRect, Rect: NSRect;
  WindowId: Pointer;
begin
  { Create our main window and center it to the main screen }
  Screen := TNSScreen.Wrap(TNSScreen.OCClass.mainScreen);
  ScreenRect := Screen.frame;
  Rect.origin.x := 0.5 * (ScreenRect.size.width - App.Width);
  Rect.origin.y := 0.5 * (ScreenRect.size.height - App.Height);
  Rect.size.width := App.Width;
  Rect.size.height := App.Height;

  WindowId := TNSWindow.Alloc.initWithContentRect(Rect, WINDOW_STYLE,
    NSBackingStoreBuffered, False);
  FWindow := TNSWindow.Wrap(WindowId);
  FWindow.setTitle(StrToNSStr(App.Title));
  FWindow.makeKeyAndOrderFront(WindowId);
  FWindow.setAcceptsMouseMovedEvents(True);
  FWindow.setBackgroundColor(TNSColor.Wrap(TNSColor.OCClass.blackColor));

  Rect := FWindow.frame;
  FContentRect := FWindow.contentRectForFrameRect(Rect);

  { Create a window delegate to get notified of window events, and attach it
    to the window. }
  FWindowDelegate := TWindowDelegate.Create(FWindow);
end;

class procedure TPlatformMac.Shutdown;
begin
  if (FPixelFormat <> nil) then
  begin
    FPixelFormat.release;
    FPixelFormat := nil;
  end;

  if (FContext <> nil) then
  begin
    FContext.release;
    FContext := nil;
  end;

  if (FView <> nil) then
  begin
    FView.release;
    FView := nil;
  end;

  if (FWindow <> nil) then
  begin
    FWindow.release;
    FWindow := nil;
  end;

  if (FMenuBar <> nil) then
  begin
    FMenuBar.release;
    FMenuBar := nil;
  end;
end;

{ TApplicationDelegate }

procedure TApplicationDelegate.applicationDidFinishLaunching(
  Notification: NSNotification);
begin
  { Not interested }
end;

function TApplicationDelegate.applicationDockMenu(
  sender: NSApplication): NSMenu;
begin
  { Not interested }
end;

function TApplicationDelegate.applicationShouldTerminate(
  Notification: NSNotification): NSInteger;
begin
  TPlatformMac.Terminated := True;
  Result := NSTerminateCancel;
end;

procedure TApplicationDelegate.applicationWillTerminate(
  Notification: NSNotification);
begin
  { Not interested }
end;

{ TWindowDelegate }

constructor TWindowDelegate.Create(const AWindow: NSWindow);
begin
  inherited Create;
  FWindow := AWindow;
  FWindow.setDelegate(Self);
end;

procedure TWindowDelegate.windowDidBecomeKey(notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidChangeBackingProperties(
  notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidDeminiaturize(notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidEnterFullScreen(
  notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidExitFullScreen(notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidMiniaturize(notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidMove(notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidResignKey(notification: NSNotification);
begin
  { Not interested }
end;

procedure TWindowDelegate.windowDidResize(notification: NSNotification);
begin
  { Not interested }
end;

function TWindowDelegate.windowShouldClose(Sender: Pointer): Boolean;
begin
  Assert(Assigned(FWindow));
  FWindow.setDelegate(nil);
  TPlatformMac.FApplication.terminate(Sender);
  Result := False;
end;

procedure TWindowDelegate.windowWillClose(notification: NSNotification);
begin
  { Not interested }
end;

end.
