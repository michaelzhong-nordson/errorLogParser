{*******************************************************************************
Nordson Corporation
Amherst, Ohio, USA
Copyright 1998

$Workfile: LogManagerUnit.pas$

DESCRIPTION:
   Logs maintains a list of current events .
   Deletes and creates logfiles as needed.
   Allows multiple reads or copy of files on networks
   Has onUpdateEvent

*******************************************************************************}

unit LogManagerUnit;

interface

uses
  SysUtils, Classes, syncobjs, FileCtrl,
   IsoIniFileUnit,windows;

type
// these are event classes or sources of log events
// A const array type of EnglishNames is defined below for translation purposes.
TEventClass = (
  ecMinClass,
  ecStartup,
  ecShutdown,
  ecConveyor,
  ecComm,
  ecRobot,
  ecProduction,
  ecDispense,
  ecUser,
  ecEditing,
  ecRuntime,
  ecIDSystem,
  ecTool,
  ecFluidSystem,
  ecCamera,
  ecFIS,
  ecSecurity,
  ecMaxClass);
// the following comments are for the language manager to read in
// the string names for the Event Class and Level for its translation file.
{
'Startup','Shutdown','Conveyor', 'Comm', 'Robot', 'Production', //ivlm
'Dispense', 'User', 'Editing', 'Runtime', 'IDSystem', 'Tool', //ivlm
'FluidSystem' //ivlm
}
{
'Debug', 'Event', 'Warning', 'Error'   //ivlm
}
// these are event levels of severity
TEventLevel = (
  elDebug,
  elEvent,
  elWarning,
  elError);


TEventClassFilter = set of TEventClass;

{ forward declarations}
TLogManager = class;
TLogItem = class;


//
//  TLogItem Class
//  encapsulates a loggable event, including the time stamp, event level,
//  event class, and an event string; can produce a string summarizing the event
//

TLogItem = class(TObject)
protected
   FTimeStamp : TDateTime;
   FEventString : string;
   FEventLevel : TEventLevel;
   FEventCLass : TEventClass;
   FBriefDateTimeFormatString : string;
   FBriefSummaryClassEnabled : boolean;
   function GetEventSummary: String; virtual;
   function GetBriefSummary: String; virtual;
public
   constructor Create; virtual;
   function Assign( Source : TLogItem ) : Boolean; virtual;
   function Duplicate : TLogItem; virtual;
   property TimeStamp : TDateTime read FTimeStamp write FTimeStamp;
   property EventString : string read FEventString write FEventString;
   property EventLevel : TEventLevel read FEventLevel write FEventLevel;
   property EventClass : TEventClass read FEventClass write FEventClass;
   property EventSummary : String read GetEventSummary;
   property BriefSummary : String read GetBriefSummary;
   property BriefDateTimeFormatString : string read FBriefDateTimeFormatString
      write FBriefDateTimeFormatString;
   property BriefSummaryClassEnabled : boolean read FBriefSummaryClassEnabled
      write FBriefSummaryClassEnabled;
end;

TLogItemWithThreadID = class( TLogItem )
protected
   FThreadID : integer;
   function GetEventSummary: String; override;
   function GetBriefSummary: String; override;
public
   constructor Create; override;
   function Assign( Source : TLogItem ) : Boolean; override;
   function Duplicate : TLogItem; override;
   property ThreadID : integer read FThreadID write FThreadID;
end;

// Delphi event declaration
TLogStatusEvent = Procedure(Sender : TObject; RecordStr : string;
  DataObject : TObject; Source : TEventClass) of object;
TLogListEvent = Procedure(Sender : TObject; EventItemList : TList) of object;
TLogTriggerEvent = Procedure(id: integer) of object;
TLogStatusEventReference = record
   pCode: pointer;
   pData: pointer;
end;

//
// TThreadBuffer
// this buffer is a TList wrapper used TLogManager to communicate
// with TLogThread; it contains a CS as well as waking up the thread
// on Add()
//

TThreadBuffer = class( TObject )
private
  FLogItemList : TList;
  FStatusList : TStringList;
  FLogThread : TThread;
  FCS : TCriticalSection;
  function GetLogItemCount: Integer;
  function GetStatusCount: Integer;
public
  constructor Create;
  destructor Destroy; override;
  function PushLogItem( NewItem : TLogItem ) : Boolean;
  function PopLogItem : TLogItem;
  function PushStatus( NewStatus : String ; EventClass : TEventClass;
     DataObject : TObject ) : Boolean;
  function PopStatus( var NewStatus : String;
     var EventClass : TEventClass; var DataObject : TObject) : Boolean;
  function PopLogItemsIntoList : TList;
  property LogItemCount : Integer read GetLogItemCount;
  property StatusCount : Integer read GetStatusCount;
  property LogThread : TThread read FLogThread write FLogThread;
end;

TBufferItem = class( TObject )
private
  FEventClass: TEventClass;
  FDataObject: TObject;
public
  constructor Create;
  destructor Destroy; override;
  property EventClass : TEventClass read FEventClass write FEventClass;
  property DataObject : TObject read FDataObject write FDataObject;
end;

//
// TLogThread
// this is used to buffer events to VCL objects, such as updating a display
// of log items or status
//

TLogThread = class( TThread )
private
  FBuffer : TThreadBuffer;
  FLog : TLogManager;
  FNewLogEntryEvent: TEvent;
  FShuttingDown: Boolean;
protected
  procedure Execute; override;
  procedure SendLogItem;
  procedure SendStatus;
public
  constructor Create( Log : TLogManager; Buffer : TThreadBuffer );
  destructor Destroy; override;
  property NewLogEntryEvent : TEvent read FNewLogEntryEvent;
end;

TTriggerRecord = class(TObject)
public
   triggerID: integer;
   triggerCaption: string;
   triggerCallback: TLogTriggerEvent;
   triggerDelayOn: Boolean;
   triggerDelayMilliseconds: integer;
   triggerTime: TDateTime;
   constructor Create(id: integer; callback: TLogTriggerEvent; cap: string);
end;

TLogItemClass = class of TLogItem;

//
// TLogManager
// This handles all logging operations and is the main interface for clients
// of the logging system
//

TTriggerStringList = class (TObject)
private
   FWildcardStrings : TStringList;
   FExactStrings: TStringList;
   //FFoundTriggers: TStringList;
public
   destructor Destroy; override;
   constructor Create;
   function Find(const S: string): TStringList;
   function AddTrigger(const S: string; AObject: TObject): Integer;
//   property FoundTriggers: TStringList read FFoundTriggers write FFoundTriggers;
end;
{TTriggerStringListOld = class (TStringList)
private
   FWildcardStrings : TStringList;
   FExactStrings: TStringList;
   //FFoundTriggers: TStringList;
public
   destructor Destroy; override;
   constructor Create;
   function Find(const S: string): TStringList;
   function AddTrigger(const S: string; AObject: TObject): Integer;
//   property FoundTriggers: TStringList read FFoundTriggers write FFoundTriggers;
end;
}
TTriggerStringListOld = class (TStringList)
private
   FPartialStrings : TStringList;
public
   destructor Destroy; override;
   function Find(const S: string; var Index: Integer): Boolean; override;
   function AddObject(const S: string; AObject: TObject): Integer; override;
end;
TLogManager = class(TObject)
private
   { Private declarations }
   FLogPath : string; // path to the log directory
   FFileList : TStringList; // used to find the log files
//   FOnLogUpdate : TLogListEvent; // event generated with each log entry
   FOnLogUpdate1 : TLogListEvent; // event generated with each log entry
   FOnLogUpdate2 : TLogListEvent; // event generated with each log entry
//   FOnStatusUpdate: TLogStatusEvent;

   FThreadBuffer : TThreadBuffer;
   FThread : TLogThread;
   FFileFilter: TEventClassFilter;
   FDisplayFilter: TEventClassFilter;
   FDisplayFilterLevel: TEventLevel;
   FFileFilterLevel: TEventLevel;
   FUnpaddedLevelMap : TStringList;
   FUnpaddedClassMap : TStringList;
   FMaxNumberLogFiles: integer;
   FDataFileName: string;
   FFileBufferList : TList;
   FBufferDepth: integer;
   FDumpBufferSize: integer;
   FLogItemClass : TLogItemClass;
   FTriggerList: TTriggerStringList;
   FDelayedTriggers: TStringList;
   FDumpBufferList : TList;
   FPostErrorCountdown: integer;
   FPostErrorMessages: integer;
   FMainVCLThreadID: THandle;
   FMessageDepth: integer;
    FTriggerEnable: Boolean;

   function FlushFileBuffer : boolean;
   procedure HandleTrigger(trig: TTriggerRecord);
   procedure DelegateTrigger(trig: TTriggerRecord);
   function GetStatusSubscriberCount: integer;
    procedure SetTriggerEnable(const Value: Boolean);
   //  SingletonCS : TCriticalSection;
protected
  { Protected declarations }
  FLogCriticalSection : TCriticalSection;
  FStatusCriticalSection : TCriticalSection;
  FBriefDateTimeFormatString : string;
  FBriefSummaryClassEnabled : boolean;
  StatusSubscribers: Array of TLogStatusEvent;
  constructor SpecialCreate;
  function InsertLogEntry(LogItemIn : TLogItem) : Boolean;
  function WriteLogEntryToFile( LogItem : TLogItem ) : Boolean;
  function WriteLogEntryToDisplayBuffer( LogItem : TLogItem ) : Boolean;
  function RemoveOldLogFiles : Boolean;
  function GenerateLogFileName( LogItem : TLogItem ) : string;
  function IsItemInFilter( FilterLevel : TEventLevel; FilterClasses : TEventClassFilter;
   LogItem : TLogItem ) : boolean;
  function OpenFileForWriting(FName: String; var FStream : TFileStream): boolean;
  function CreateLogDirectoryIfNeeded : Boolean;
  function LogItemFactory : TLogItem;
public
  { Public declarations }
  constructor Create;
  procedure SetStatus(EventClass: TEventClass; const Value: string;
                   DataObject : TObject);
  procedure PadStrings;
  class function Instance : TLogManager;
  destructor Destroy; override;
  function LogDebug( EventClass : TEventClass; EventString : String ) :
           Boolean;
  function LogEvent( EventClass : TEventClass; EventString : String ) :
           Boolean;
  function LogWarning( EventClass : TEventClass; EventString : String ) :
           Boolean;
  function LogError( EventClass : TEventClass; EventString : String ) :
           Boolean;
  function LogMessage( EventLevel: TEventLevel; EventClass : TEventClass; EventString : String ) :
           Boolean;
  function LogStrings( EventLevel: TEventLevel; EventClass : TEventClass; EventStrings : TStrings; prefix: string ) :
           Boolean;
  function SaveFilterStateToIniFile( IFile : TIsoIniFile ) : Boolean;
  function FlushLog : Boolean;
  function LoadFilterStateFromIniFile( IFile : TIsoIniFile ) : Boolean;
  function AddLogTrigger(triggerID: integer; triggerString: string;
     callbackFunction: TLogTriggerEvent; caption: string; delayMilliseconds: integer=0): Boolean;
  procedure TBD(EventString: string);
  procedure AddStatusSubscriber(subscriber: TLogStatusEvent);
  procedure RemoveStatusSubscriber(subscriber: TLogStatusEvent);
  procedure ShutdownNotify;
  procedure ProcessMessages;
  procedure SwitchToDebugMode;
  property ClassMap: TStringList read FUnPaddedClassMap;
  property LevelMap: TStringList read FUnpaddedLevelMap;
  property LogThread : TLogThread read FThread;
  property DataFileName : string read FDataFileName write FDataFileName;
  property StatusSubscriberCount: integer read GetStatusSubscriberCount;
  property TriggerEnable: Boolean read FTriggerEnable write SetTriggerEnable;
//  property OnStatusUpdate : TLogStatusEvent read FOnStatusUpdate
//          write FOnStatusUpdate;
//taj published
  { Published declarations }
  property FileFilter : TEventClassFilter read FFileFilter
   write FFileFilter;
  property FileFilterLevel : TEventLevel read FFileFilterLevel
   write FFileFilterLevel;
  property DisplayFilter : TEventClassFilter read FDisplayFilter
   write FDisplayFilter;
  property DisplayFilterLevel : TEventLevel read FDisplayFilterLevel
   write FDisplayFilterLevel;
  property MaxNumberLogFiles : integer read FMaxNumberLogFiles
   write FMaxNumberLogfiles;
  property LogPath : string read FLogPath write FLogPath;
//  property OnLogUpdate : TLogListEvent read FOnLogUpdate
//          write FOnLogUpdate;
  property OnLogUpdate1 : TLogListEvent read FOnLogUpdate1
          write FOnLogUpdate1;
  property OnLogUpdate2 : TLogListEvent read FOnLogUpdate2
          write FOnLogUpdate2;
  property BriefDateTimeFormatString : string read FBriefDateTimeFormatString
          write   FBriefDateTimeFormatString;
  property BriefSummaryClassEnabled : boolean read FBriefSummaryClassEnabled
         write FBriefSummaryClassEnabled;

end;

// these two functions use RTTI methods to get strings out of the
// enumerated types
function GetEventClass( EventClass : TEventClass ): String;
function GetEventLevel( EventLevel : TEventLevel): String;

implementation

uses
 Forms,
 Dialogs,
 typinfo,
 ivDictio;

var
  SingletonInstance : TLogManager; // singleton reference
  FEventLevelMap : TStringList; // holds the map of enumerated values to their
                                // string representations
  FEventClassMap : TStringList; // holds the map of enumerated values to their
                                // string representations
  {
  FEventLevelMap : TStringList; // holds the map of enumerated values to their
                                // string representations
  FEventClassMap : TStringList; // holds the map of enumerated values to their
                                // string representations
  MaxClass : integer; // maximum class value
  MaxLevel : integer; // maximum level value
  pti : PTypeInfo;
  ptd : PTypeData;
  IndexI, IndexJ, IndexK : integer;
  SingletonCS : TCriticalSection;
  EnumString : string;
  }
const
  newLine = #13#10; // CR and LF
  MAX_BUFFERED_ITEMS = 500; //
  DEFAULT_INIFILESECTION = 'Log Settings';  //no trans
  DEFAULT_MAX_LOG_FILES = 15;
  DEFAULT_FILE_BUFFER_DEPTH = 50;
  DEFAULT_BRIEF_FORMAT = 'hh:mm:ss.zzz'; //no trans
  BUFFER_DEPTH_KEY = 'BufferDepth'; //no trans
  DUMP_BUFFER_SIZE_KEY = 'Dump Buffer Size'; //no trans
  DEFAULT_DUMP_BUFFER_SIZE = 500;
  DUMP_POST_ERROR_MESSAGES_KEY = 'Post Error Messages'; //no trans
  DEFAULT_DUMP_POST_ERROR_MESSAGES = 100;


// Logger destructor
procedure TLogManager.DelegateTrigger(trig: TTriggerRecord);
begin
  //note that the delays are minimums; there needs to be another
  //message logged to check for any delayed messages.
  //However, with the real machine, there is constant communication, so
  //there are frequent checks of these delayed log triggers.
  if trig.triggerDelayOn then
  begin
     FDelayedTriggers.AddObject(trig.triggerCaption,trig);
     if trig.triggerDelayMilliseconds > 0 then
     begin
        //convert the milliseconds to days
        trig.triggerTime := now + (trig.triggerDelayMilliseconds/(1000*3600*24));
     end
     else
     begin
        //a negative delay means make it random up to the magnitude of the delay
        trig.triggerTime := now + (Random(0-trig.triggerDelayMilliseconds)/(1000*3600*24));
     end;
  end
  else
  begin
     HandleTrigger(trig);
  end;

end;

destructor TLogManager.destroy;
   begin

   // free file buffer
   // there shouldn't be any entries left by the time we get here (see finalization call to flushlog)
   // but delete them in any case - it is too late to do anything useful with them
   while( FFileBufferList.Count > 0 ) do
   begin
      TLogItem( FFileBufferList.Items[0] ).Free;
      FFileBufferList.Delete(0);
   end;
   FFileBufferList.Free;
   while( FDumpBufferList.Count > 0 ) do
   begin
      TLogItem( FDumpBufferList.Items[0] ).Free;
      FDumpBufferList.Delete(0);
   end;
   FDumpBufferList.Free;

   // free up variables associated with limiting the number of log files
   if assigned(FFileList) then
   begin
   FFileList.clear;
   FFileList.free;
   end;

   // free critical sections
   FLogCriticalSection.Free;
   FStatusCriticalSection.Free;

   while( FUnPaddedLevelMap.Count > 0 ) do
   begin
      FUnPaddedLevelMap[0] := '';   //no trans
      FUnPaddedLevelMap.Delete(0);
   end;
   FUnPaddedLevelMap.Free;

   while( FUnPaddedClassMap.Count > 0 ) do
   begin
      FUnPaddedClassMap[0] := '';   //no trans
      FUnPaddedClassMap.Delete(0);
   end;

   FUnPaddedClassMap.Free;

   // terminate thread
   FThread.Terminate; // thread is responsible for Freeing ThreadBuffer
   FThread.WaitFor;
   FThread.Free;

   {
   while FTriggerList.Count > 0 do
   begin
      FTriggerList.Objects[0].Free;
      FTriggerList.Delete(0);
   end;
   }
   FTriggerList.Free;

   while FDelayedTriggers.Count > 0 do
   begin
      //these objects are duplicates of the trigger list,
      //so only delete the list items, do not free
      //the objects
      FDelayedTriggers.Delete(0);
   end;
   FDelayedTriggers.Free;


   inherited Destroy;
end;


// Log an event of level Event
function TLogManager.LogEvent(EventClass: TEventClass; EventString: String)
         : Boolean;
var
   NewLogItem : TLogItem;
begin

     // create new log Item;
     try
        NewLogItem := LogItemFactory;
     except
        result := FALSE;
        exit;
     end;
     NewLogItem.EventString := EventString;
     NewLogItem.EventClass := EventClass;
     NewLogitem.EventLevel := elEvent;
     // insert item into log
     result := InsertLogEntry( NewLogItem );
end;

// log an event of level Error
function TLogManager.LogError(EventClass: TEventClass;
  EventString: String): Boolean;
var
   NewLogItem : TLogItem;
begin
     // create new log Item;
     try
        NewLogItem := LogItemFactory;
     except
        result := FALSE;
        exit;
     end;
     NewLogItem.EventString := EventString;
     NewLogItem.EventClass := EventClass;
     NewLogitem.EventLevel := elError;
     // insert item into log
     result := InsertLogEntry( NewLogItem );
end;

// log an event of level Warning
function TLogManager.LogWarning(EventClass: TEventClass;
  EventString: String): Boolean;
var
   NewLogItem : TLogItem;
begin
     // create new log Item;
     try
        NewLogItem := LogItemFactory;
     except
        result := FALSE;
        exit;
     end;
     NewLogItem.EventString := EventString;
     NewLogItem.EventClass := EventClass;
     NewLogitem.EventLevel := elWarning;
     // insert item into log
     result := InsertLogEntry( NewLogItem );
end;


// insert TLogItem into log
function TLogManager.InsertLogEntry(LogItemIn: TLogItem) : Boolean;
var
   i: integer;
   //matchIndex: integer;
   triggeredItems,testItem: string;
   tmpFoundList: TStringList;
begin
   // enter CS
   FLogCriticalSection.Enter;

   try
      result := WriteLogEntryToFile( LogItemIn);

      if result and TriggerEnable then
      begin
         //add this new section here, because sending it to
         //the display buffer means we are done with it and it
         //may be freed.
         tmpfoundList := FTriggerList.Find(LogItemIn.EventString);
         if assigned(tmpFoundList) then
         begin
            //there is at least one trigger, so go through the list
            while tmpFoundList.Count > 0 do
            begin
               DelegateTrigger(TTriggerRecord(tmpFoundList.Objects[0]));
               tmpFoundList.Delete(0);
            end;
            tmpFoundList.Free;
         end;
         {
         if FTriggerList.Find(LogItemIn.EventString,matchIndex) then
         begin
            //this is a trigger
            DelegateTrigger(TTriggerRecord(FTriggerList.Objects[matchIndex]));
            //check if there are more than one trigger registered for this string
            //find will have returned the first one in the list
            triggeredItems := IntToStr(Integer(FTriggerList.Objects[matchIndex]))+' ';//no trans
            i := matchIndex + 1;
//changed for version 481
            while  ( i < FTriggerList.Count)
//            while  ( i < Pred(FTriggerList.Count))
            and    ( AnsiCompareText(FTriggerList[matchIndex],FTriggerList[i])=0 ) do
            begin
               //we have another trigger for this string
               //for language independence, we have two strings in the list for the same trigger
               //one is translated, and one is not. However, the translated string might still be native
               //in which case we end up here
               //so check the string of the pointer
               testItem := IntToStr(Integer(FTriggerList.Objects[i]))+' '; //no trans
               if AnsiPos(testItem,triggeredItems)<= 0 then
               begin
                  //this one has not been done yet
                  triggeredItems := triggeredItems + testItem;
                  DelegateTrigger(TTriggerRecord(FTriggerList.Objects[i]));
               end;
               inc(i);
            end;
         end;
         }
         //check any delayed triggers we are monitoring
         if FDelayedTriggers.Count > 0 then
         begin
            //this is a list of the delayed guys
            for i := FDelayedTriggers.Count - 1 downto 0 do
            begin
               //start at the end in case we delete one
               if (now > TTriggerRecord(FDelayedTriggers.Objects[i]).triggerTime)then
               begin
                  HandleTrigger(TTriggerRecord(FDelayedTriggers.Objects[i]));
                  FDelayedTriggers.Delete(i);
               end;
            end;
         end;
      end;

      if result then
      begin
         result := WriteLogEntryToDisplayBuffer( LogItemIn );
      end;
   finally
      // leave CS
      FLogCriticalSection.Leave;
   end;
end;


//
//  TLogItem
//

// copy contents of a TLogItem into self
function TLogItem.Assign(Source: TLogItem): Boolean;
begin
  if Assigned( Source ) then
  begin
    FTimeStamp := Source.TimeStamp;
    FEventString := Source.EventString;
    FEventLevel := Source.EventLevel;
    FEventCLass := Source.EventClass;
    result := TRUE;
  end
  else
  begin
     result := FALSE;
  end;
end;

// create a log item
constructor TLogItem.create;
begin
  inherited Create;
  TimeStamp := Now;
end;

// return the string summarizing the event
function TLogItem.Duplicate: TLogItem;
begin
   result := TLogItem.Create;
   result.Assign( self );
end;

function TLogItem.GetBriefSummary: String;
begin

 // DecodeTime(TimeStamp, Hour, Min, Sec, MSec);
//  result := FormatDateTime('YYYY-MMM-DD hh:mm:ss', TimeStamp)  //no trans
//        + format('.%.3d ',[MSec]);  //no trans
  result := FormatDateTime(BriefDateTimeFormatString,TimeStamp);  //no trans

  // optionally include the class (e.g., startup, robot, shutdown, etc.)
  if( FBriefSummaryClassEnabled ) then
     result := result + ' ' + Translate(GetEventClass( EventClass ));   //no trans

  // now include the event message itself
  result := result + '  ' + EventString;  //no trans
end;

function TLogItem.GetEventSummary: String;
var
   Hour, Min, Sec, Msec : Word;
begin

  DecodeTime(TimeStamp, Hour, Min, Sec, MSec);
  result := FormatDateTime('YYYY-MMM-DD hh:mm:ss', TimeStamp)  //no trans
        + format('.%.3d ',[MSec]);  //no trans
  result := result + ' ' + Translate(GetEventLevel( EventLevel ));  //no trans
  result := result + ' ' + Translate(GetEventClass( EventClass ));   //no trans
  result := result + '  ' + EventString;  //no trans

end;


// map enumerated event class type to a string
function GetEventClass( EventClass : TEventClass ): String;
var
   EvtClass : Integer;
begin
     EvtClass := Ord( EventClass );
     if( ( EvtClass < FEventClassMap.Count ) and ( EvtClass >= 0 ) ) then
          begin
               result := FEventClassMap[ EvtClass ];
          end
     else
          begin
               result := '';  //no trans
          end;
end;

// map enumerated event level type to a string
function GetEventLevel( EventLevel : TEventLevel): String;
var
   EvtLevel : Integer;
begin
     EvtLevel := Ord(EventLevel);

     if( ( EvtLevel < FEventLevelMap.Count ) and ( EvtLevel >= 0 ) ) then
          begin
               result := FEventLevelMap[ EvtLevel ];
          end
     else
          begin
               result := '';  //no trans
          end;

end;

procedure TLogManager.AddStatusSubscriber(subscriber: TLogStatusEvent);
var
   i: integer;
   pCurrent,pTarget: TLogStatusEventReference;
   tmpFound : Boolean;

begin
   i := 0;
   //added a check to prevent another bug related to adding duplicate status
   //subscribers and deleting one later (leaving one around to cause AVs)
   tmpFound := False;
   pTarget := TLogStatusEventReference(subscriber);
   while i < Length(StatusSubscribers) do
   begin
      pCurrent := TLogStatusEventReference(StatusSubscribers[i]);
      if pCurrent.pData = pTarget.pData then
      begin
         tmpFound := True;
      end;
      inc(i);
   end;
   if tmpFound then
   begin
      LogError(ecRuntime, 'Duplicate Status Subscriber'); //no trans
   end
   else
   begin
      SetLength(StatusSubscribers,Length(StatusSubscribers)+1);
      StatusSubscribers[Length(StatusSubscribers)-1] := subscriber;
   end;
end;

constructor TLogManager.Create;
begin
     ShowMessage(Translate('Error: TLogManager Constructor Called!!!!'));  //no trans
end;

class function TLogManager.Instance: TLogManager;
begin

{
  if( SingletonInstance = nil ) then
  begin
    // enter CS
    SingletonCS.Enter;

    // double-checked locking; this second test of SingletonInstance
    // is important!  don't remove
    if( SingletonInstance = nil ) then
    begin
      SingletonInstance := TLogManager.SpecialCreate;
    end;

    // leave CS
    SingletonCS.Leave;
  end;
 }
  result := SingletonInstance;
end;

constructor TLogManager.SpecialCreate;
var
   i : integer;
begin
  try
    inherited Create;

    FMainVCLThreadID := GetCurrentThreadID();
    // setup default log item brief date time format string
    BriefDateTimeFormatString := DEFAULT_BRIEF_FORMAT;// 'YYYY-MMM-DD hh:mm:ss.zzz';//no trans

    // default to include the class in the brief event summary (used for display)
    FBriefSummaryClassEnabled := TRUE;

    // setup startup CS
//    SingletonCS := TCriticalSection.Create;

   // initialize log item factory class
   FLogItemClass := TLogItemWithThreadID; // by default log the thread IDs
   // this gets us full debugging by default (i.e., when the /d command-line option is used)

    // create critical sections
    FLogCriticalSection := TCriticalSection.Create;
    FStatusCriticalSection := TCriticalSection.Create;

    // create buffer
    FThreadBuffer := TThreadBuffer.Create;

    // create file buffer
    FFileBufferList := TList.Create;
    FFileBufferList.Capacity := 1; // by default the buffer is one entry deep-ie, no buffering
    FDumpBufferList := TList.Create;
    FDumpBufferList.Capacity := DEFAULT_DUMP_BUFFER_SIZE; //dump this many messages when error occurs

    // create log thread
    FThread := TLogThread.Create( self, FThreadBuffer );
    for i := 0 to 100 do
    begin
      if( Fthread.NewLogEntryEvent.WaitFor(300) = wrSignaled ) then
         begin
            break;
         end
      else if (i = 100) then
         begin
             // error creating log thread
           ShowMessage(Translate('Error Creating Log Thread!'));  //no trans
           exit;
         end;
      Application.ProcessMessages;
    end;
    FThread.Resume;

    FThreadBuffer.LogThread := FThread;

    FLogPath := ExtractFilePath(application.ExeName) + 'LOG\'; //no trans

    // by default, log everything to file and display
    FDisplayFilter := [ecMinClass..ecMaxClass];
    FFileFilter := [ecMinClass..ecMaxClass];

    // set level to log everything
    FDisplayFilterLevel := elEvent;
    FFileFilterLevel := elEvent;

    // create maps
    FUnpaddedLevelMap := TStringList.Create;
    FUnpaddedClassMap := TStringList.Create;

    // set max number of files
    FMaxNumberLogFiles := DEFAULT_MAX_LOG_FILES;

    //create the class name maps
    FEventClassMap := TStringList.Create;
    FEventLevelMap := TStringList.Create;

    //make the list of triggers
    FTriggerList := TTriggerStringList.Create;

    //make the list of delayed triggers
    //it holds any pending delays, so the contents are temporary
    FDelayedTriggers := TStringList.Create;
    FDelayedTriggers.Duplicates := dupAccept;

    FMessageDepth := 0;

    FTriggerEnable := True;

  except
     ShowMessage(Translate('Fatal error starting logging system.')); //no trans
     raise;
  end;
end;



procedure TLogManager.SwitchToDebugMode;
begin
   LogEvent( ecruntime, 'Switching to Debug Log Mode');  //ivlm
   DisplayFilter := [ecMinClass..ecMaxClass];
   FileFilter := [ecMinClass..ecMaxClass];

   // set level to log everything
   DisplayFilterLevel := elDebug;
   FileFilterLevel := elDebug;

end;

procedure TLogManager.TBD(EventString: string);
begin
   //this is a function to catch and log TBD items
   //for now, log a warning
   LogWarning(ecStartup,'TBD: '+EventString); // no trans
end;

{ TLogThread }

constructor TLogThread.Create( Log : TLogManager; Buffer: TThreadBuffer);
begin
  FreeOnTerminate := False;
  FBuffer := Buffer;
  FLog := Log;
  FNewLogEntryEvent := TEvent.Create( nil, FALSE, FALSE, '');  //no trans
  FShuttingDown := False;
  inherited Create( True );
  FNewLogEntryEvent.SetEvent;
end;

destructor TLogThread.Destroy;
begin
  FBuffer.Free;
  FNewLogEntryEvent.Free;
  inherited Destroy;
end;

procedure TLogThread.Execute;
begin

  while( NOT ( Terminated ) )do
  begin
    // sleep until something appears in buffer
    FNewLogEntryEvent.Waitfor( 100 ) ;

    // if we've woken up, then there should be something
    // in the buffer (although we might have timed-out which is handled)

    // see if the log item event is connected and there are any events
{    while( NOT( Terminated )
     AND Assigned( FLog.OnLogUpdate )
     AND ( FBuffer.LogItemCount > 0 ) )do
    begin
      Synchronize( SendLogItem );
    end;
}
    while( NOT( Terminated )
     AND Assigned( FLog.OnLogUpdate1 )
     AND ( FBuffer.LogItemCount > 0 ) )do
    begin
      Synchronize( SendLogItem );
    end;
    while( NOT( Terminated )
     AND Assigned( FLog.OnLogUpdate2 )
     AND ( FBuffer.LogItemCount > 0 ) )do
    begin
      Synchronize( SendLogItem );
    end;

    // see if the status string event is connected and there are any status lines
    while( NOT( Terminated )
//     AND Assigned( FLog.OnStatusUpdate )
     AND (FLog.StatusSubscriberCount > 0)
     AND (FBuffer.StatusCount > 0 )
     AND (not FShuttingDown) )do
    begin
      Synchronize( SendStatus );
    end;
  end;
end;

procedure TLogThread.SendLogItem;
var
   tmpList1, tmpList2: Tlist;
   Loop: integer;
begin
//   if Assigned (FLog.OnLogUpdate) then FLog.OnLogUpdate( FLog, FBuffer.PopLogItemsIntoList );
   if Assigned (FLog.OnLogUpdate1) then
   begin
      tmpList1 := FBuffer.PopLogItemsIntoList;
      if assigned (FLog.OnLogUpdate2) then
      begin
         tmpList2 := TList.Create;
         for Loop := 0 to tmpList1.Count - 1 do
         begin
            tmpList2.Add(tmpList1.Items[Loop]);
         end;
         if Assigned(tmpList2) then
         begin
            FLog.OnLogUpdate2( FLog, tmpList2 );
         end;
      end;
      if Assigned(tmpList1)  then
         try
            FLog.OnLogUpdate1( FLog, tmpList1 );
         except

         end;
  end;
end;

procedure TLogThread.SendStatus;
var
  status : string;
  eventclass : TEventClass;
  dataobject : TObject;
  i: integer;

begin
  if( FBuffer.PopStatus( status, eventclass, dataobject) ) then
  begin
     if FLog.StatusSubscriberCount > 0 then
     begin
        for i := 0 to FLog.StatusSubscriberCount - 1 do
        begin
  //         tmpPtr := FLog.StatusSubscribers[i];
//           tmpProc := TLogStatusEvent(tmpPtr);
           FLog.StatusSubscribers[i](FLog,Status,dataObject,eventClass);
        end;
        //policy with these is to not free.
        dataObject.Free;
     end
{     else if Assigned(FLog.OnStatusUpdate) then
     begin
        FLog.OnStatusUpdate( FLog, status, dataobject, eventclass )
     end
}
     else
     begin
        dataObject.Free;
     end;
  end
end;


{ TThreadBuffer }

constructor TThreadBuffer.Create;
begin
  // object calling this constructor will handle any exceptions on Create
  inherited Create;
  FCS := TCriticalSection.Create;
  FLogItemList := TList.Create;
  FLogItemList.Capacity := MAX_BUFFERED_ITEMS;
  FStatusList := TStringList.Create;
  FStatusList.Sorted := FALSE;
  FStatusList.Capacity := MAX_BUFFERED_ITEMS;
  FLogThread := nil;
end;

destructor TThreadBuffer.Destroy;
begin
     while( FLogItemList.Count > 0 ) do
     begin
          TLogItem( FLogItemList.Items[0] ).Free;
          FLogItemList.Delete( 0 ) ;
     end;
     FLogItemList.Free;

     //free the buffer items
     while( FStatusList.Count > 0 ) do
     begin
          FStatusList.Objects[0].Free;
          FStatusList.Delete( 0 ) ;
     end;
     FStatusList.Free;
     FCS.Free;

     inherited Destroy;
end;

function TThreadBuffer.GetLogItemCount: Integer;
begin
     result := FLogItemList.Count;
end;

function TThreadBuffer.GetStatusCount: Integer;
begin
     result := FStatusList.Count;
end;

function TThreadBuffer.PopLogItem: TLogItem;
begin
     FCS.Enter;
     if( FLogItemList.Count > 0 ) then
     begin
          result := TLogItem( FLogItemList.Items[0] );
          FLogItemList.Delete(0);
     end
     else
     begin
          result := nil;
     end;
     FCS.Leave;
end;

function TThreadBuffer.PopLogItemsIntoList: TList;
begin
   FCS.Enter;

   result := TList.Create; // create list to hold entries

   result.Capacity := FLogItemList.Count; // allocate enough space to save time

   while( FLogItemList.Count > 0 ) do
   begin
       result.Add( FLogItemList.Items[0] ); // move log item pointer into list
       FLogItemList.Delete(0); // remove item from buffer
   end;
   FCS.Leave;

end;

function TThreadBuffer.PopStatus( var NewStatus : String;
        var EventClass : TEventClass; var DataObject : TObject ) : Boolean;
var
  TempItem : TBufferItem;
begin
     FCS.Enter;
     if( FStatusList.Count > 0 ) then
     begin
          NewStatus := FStatusList.Strings[0];
          TempItem := TBufferItem( FStatusList.Objects[0] );
          FStatusList.Delete( 0 );
          EventClass := TempItem.EventClass;
          //here, we effectively move the data object
          DataObject := TempItem.DataObject;
          //by setting its pointer
          TempItem.DataObject  := nil;
          //so tempItem.Free does not destroy the Data Object
          TempItem.Free;
          result := TRUE;
     end
     else
     begin
          result := FALSE;
     end;
     FCS.Leave;

end;

function TThreadBuffer.PushLogItem(NewItem: TLogItem): Boolean;
begin
     FCS.Enter;
     // when running full-tilt, too many log messages may be generated;
     // something has to give, so delete the oldest insructions from buffer,
     // they have already been logged to the file, so we are only cheating
     // the graphical display; there's no
     // sense is consuming a bunch of memory when these items
     // will quickly scroll out of the display buffer when displayed;
     // the list capacity should be greater than that of the display buffer
     while( FLogItemList.Count > ( FLogItemList.Capacity - 1 ) ) do
     begin
        TLogItem( FLogItemList.Items[0] ).Free;
        FLogItemList.Delete( 0 );
     end;

     FLogItemList.Add( NewItem );

     FCS.Leave;
     if Assigned( FLogThread ) then
        TLogThread(FLogThread).NewLogEntryEvent.SetEvent;
     result := TRUE;
end;

function TThreadBuffer.PushStatus( NewStatus : String ;
  EventClass : TEventClass; DataObject : TObject ) : Boolean;
var
  index : integer;
  tempitem : TBufferItem;
begin
     FCS.Enter;
     // see comments for PushLogItem
     while( FStatusList.Count > ( FStatusList.Capacity - 1 ) ) do
     begin
        FStatusList.Objects[0].Free;
        FStatusList.Delete( 0 );
     end;

     index := FStatusList.Add( NewStatus );

     try
        TempItem := TBufferItem.Create;
     except
        result := FALSE;
        FCS.Leave;
        exit;
     end;

     TempItem.EventClass := EventClass;
     TempItem.DataObject := DataObject;
     FStatusList.Objects[ index ] := TempItem;
     FCS.Leave;
     if Assigned( FLogThread ) then
        TLogThread(FLogThread).NewLogEntryEvent.SetEvent;
     result := TRUE;
end;


function TLogManager.LoadFilterStateFromIniFile(IFile: TIsoIniFile): Boolean;
var
  TempString : string;
  i : integer;
  tempClass : TEventClass;
  classString: string;
  strTmp: string;
begin
   //if there is no section for us, then write one.
   if not IFile.SectionExists( DEFAULT_INIFILESECTION ) then SaveFilterStateToIniFile(IFile);
   // get number of files
   FMaxNumberLogFiles := IFile.ReadInteger( DEFAULT_INIFILESECTION,
      'MaxNumberLogFiles', //no trans
      DEFAULT_MAX_LOG_FILES, 'How many log files to allow on the hard drive. '//no trans
      +'Oldest is deleted when this number is exceeded.'); //no trans

   // remove old files
   if NOT RemoveOldLogFiles then
   begin
      ShowMessage(Translate('Error removing old log files'));
   end;

  // get file filter state
  TempString := IFile.ReadString( DEFAULT_INIFILESECTION, 'FileLogLevel', 'Event', //no trans
  'Error, Warning, Event, or Debug are possible values. Events of this level or '//no trans
  +'more severe are logged into the log file.');   //no trans
  FFileFilterLevel := TEventLevel(
   GetEnumValue( Typeinfo (TEventLevel), 'el' + TempString) ); //no trans

  // get the buffering level
  FFileBufferList.Capacity := IFile.ReadInteger( DEFAULT_INIFILESECTION, BUFFER_DEPTH_KEY, //no trans
   DEFAULT_FILE_BUFFER_DEPTH, 'How many messages to buffer before dumping into the log file. '+//no trans
   'numbers greater than 1 improve performance, but most recent messages may be missing '+//no trans
   'in the event of a software crash.'); //no trans
  FBufferDepth := FFileBufferList.Capacity;

  //the dump buffer settings might not be there, so add them only if they
  //are not present.  If they are present, we do not want to add them,
  //or we will overwrite custom settings
  strTmp := IFile.ReadString( DEFAULT_INIFILESECTION, DUMP_BUFFER_SIZE_KEY, //no trans
      '', 'SUPPRESS'); //no trans
   if strTmp = '' then //no trans
   begin
      IFile.WriteInteger( DEFAULT_INIFILESECTION, DUMP_BUFFER_SIZE_KEY, //no trans
         DEFAULT_DUMP_BUFFER_SIZE);
   end;
  strTmp := IFile.ReadString( DEFAULT_INIFILESECTION, DUMP_POST_ERROR_MESSAGES_KEY, //no trans
      '', 'SUPPRESS'); //no trans
   if strTmp = '' then //no trans
   begin
      IFile.WriteInteger( DEFAULT_INIFILESECTION, DUMP_POST_ERROR_MESSAGES_KEY, //no trans
         DEFAULT_DUMP_POST_ERROR_MESSAGES);
   end;

  FDumpBufferSize := IFile.ReadInteger( DEFAULT_INIFILESECTION, DUMP_BUFFER_SIZE_KEY, //no trans
      DEFAULT_DUMP_BUFFER_SIZE, 'If nonzero, then when an error is logged, the proceeding debug messages are also inserted in the log, even when not in debug mode'); //no trans
  if FDumpBufferSize > 0 then
  begin
     FDumpBufferList.Capacity := FDumpBufferSize;
  end;
  FPostErrorMessages := IFile.ReadInteger( DEFAULT_INIFILESECTION, DUMP_POST_ERROR_MESSAGES_KEY, //no trans
      DEFAULT_DUMP_POST_ERROR_MESSAGES, 'If nonzero, then when an error is logged, this many debug messages follow the error'); //no trans
  // get file filter classes
  // skip first and last entries in list
  for i := 1 to Pred(FUnPaddedClassMap.Count) - 1 do
  begin
   tempClass := TEventClass( i );
   classString :=GetEnumName(TypeInfo(TEventClass),Ord(i));
   classString := 'FileLog' +    Copy(classString,3,Length(classString)-2);  //no trans
   if( IFile.ReadBool( DEFAULT_INIFILESECTION, classString {'[An event class]'}, TRUE,  //no trans
      'If true, then this class of messages will be included in the display.' ) ) then  //no trans
   begin
     FFileFilter := FFileFilter + [tempClass];
   end
   else
     FFileFilter := FFileFilter - [tempClass];
  end;

  // get display filter state
  TempString := IFile.ReadString( DEFAULT_INIFILESECTION, 'DisplayLogLevel', 'Event', //no trans
  'Error, Warning, Event, or Debug are possible values. Events of this level or '//no trans
  +'more severe are logged in the event monitor.');   //no trans
  FDisplayFilterLevel := TEventLevel(
   GetEnumValue( Typeinfo (TEventLevel), 'el' + TempString));  //no trans

  // get display filter classes
  // skip first and last entries in list
  for i := 1 to Pred(FUnPaddedClassMap.Count) - 1 do
  begin
   tempClass := TEventClass( i );
   classString := GetEnumName(TypeInfo(TEventClass),Ord(i));
   classString := 'DisplayLog' + Copy(classString,3,Length(classString)-2);  //no trans
   if( IFile.ReadBool( DEFAULT_INIFILESECTION, classString {'[An event class]'}, TRUE,  //no trans
      'If true, then this class of messages will be included in the display.' ) ) then //no trans
   begin
     FDisplayFilter := FDisplayFilter + [tempClass];
   end
   else
     FDisplayFilter := FDisplayFilter - [tempClass];
  end;

  // get log item class to use
  if IFile.ReadBool( DEFAULT_INIFILESECTION, 'LogThreadID', FALSE, //no trans
  'For debugging. If true, then thread IDs of source threads ' + //no trans
  'for events will be appended to log messages.' ) then  //no trans
  begin
   FLogItemClass := TLogItemWithThreadID;
//   TLogManager.Instance.LogDebug( ecruntime, 'Logging with Thread ID');  //no trans
  end
  else
  begin
   FLogItemClass := TLogItem;
//   TLogManager.Instance.LogDebug( ecruntime, 'Logging without Thread ID');  //no trans
  end;

  // get the brief (i.e., display) date time format string
  FBriefDateTimeFormatString := IFile.ReadString( DEFAULT_INIFILESECTION, 'BriefDateTimeFormatString', //no trans
   DEFAULT_BRIEF_FORMAT,
   'Operator Screen Date and Time Format String for Log Items' ); // no trans

   // see if the event class should be included in the brief event summary
   FBriefSummaryClassEnabled := IFile.ReadBool( DEFAULT_INIFILESECTION, 'BriefSummaryClassEnabled', //no trans
   TRUE,
   'Operator Screen Event Class Display (e.g., Startup, Shutdown, Robot, etc.)' ); // no trans

  result := TRUE;
end;

function TLogManager.SaveFilterStateToIniFile(IFile: TIsoIniFile): Boolean;
var
   i : integer;
   LevelString : string;
   ClassString: string;
begin
   // backup INI file first
//???   DataModuleMain.BackupIniFile;
   // save max number of files
   IFile.WriteInteger( DEFAULT_INIFILESECTION, 'MaxNumberLogFiles', //no trans
      FMaxNumberLogFiles);
   IFile.WriteInteger( DEFAULT_INIFILESECTION, BUFFER_DEPTH_KEY, //no trans
      DEFAULT_FILE_BUFFER_DEPTH);

   // write file filter state
   LevelString := GetEnumName(TypeInfo(TEventLevel),Ord(FFileFilterLevel)) ;
   LevelString := Copy(LevelString,3,Length(LevelString)-2);
   IFile.WriteString( DEFAULT_INIFILESECTION, 'FileLogLevel', LevelString);  //no trans

   // write file filter classes
   // skip first and last entries in list
   for i := 1 to Pred(FUnPaddedClassMap.Count) - 1 do
   begin
      classString := GetEnumName(TypeInfo(TEventClass),Ord(i));
      classString := 'FileLog' + Copy(classString,3,Length(classString)-2); //no trans
      if(  TEventClass( i ) in FFileFilter)then
      begin
         IFile.WriteBool( DEFAULT_INIFILESECTION, classString, TRUE);
      end
      else
      begin
         IFile.WriteBool( DEFAULT_INIFILESECTION, classString, FALSE);
      end;
   end;


   // write Displayfilter state
   LevelString := GetEnumName(TypeInfo(TEventLevel),Ord(FDisplayFilterLevel));
   LevelString := Copy(LevelString,3,Length(LevelString)-2);
   IFile.WriteString( DEFAULT_INIFILESECTION, 'DisplayLogLevel', LevelString);  //no trans

   // write file filter classes
   // skip first and last entries in list
   for i := 1 to Pred(FUnPaddedClassMap.Count) - 1 do
   begin
      classString := GetEnumName(TypeInfo(TEventClass),Ord(i));
      classString := 'DisplayLog' + Copy(classString,3,Length(classString)-2); //no trans
      if(  TEventClass( i ) in FDisplayFilter)then
      begin
         IFile.WriteBool( DEFAULT_INIFILESECTION, classString, TRUE);
      end
      else
      begin
         IFile.WriteBool( DEFAULT_INIFILESECTION, classString, FALSE);
      end;
   end;

   // write log thread id state to file
   IFile.WriteBool( DEFAULT_INIFILESECTION, 'LogThreadID', FALSE );  //no trans

   result := TRUE;
end;


procedure TLogManager.SetStatus(EventClass: TEventClass;
  const Value: string; DataObject : TObject);

begin
  FStatusCriticalSection.Enter;

  // generate event if wired
  if StatusSubscriberCount > 0 then
  begin
     FThreadBuffer.PushStatus( Value, EventClass, DataObject );
  end
{
  else
  if assigned( OnStatusUpdate ) then
      begin
         FThreadBuffer.PushStatus( Value, EventClass, DataObject );
      end
}
  else
      begin
         if Assigned( DataObject ) then
            begin
                 DataObject.Free;
            end;
      end;

  FStatusCriticalSection.Leave;

end;

procedure TLogManager.SetTriggerEnable(const Value: Boolean);
begin
  FTriggerEnable := Value;
  if Value then
  begin
     LogDebug(ecRuntime, 'Log Triggers Enabled'); //no trans
  end
  else
  begin
     LogDebug(ecRuntime, 'Log Triggers Disabled'); //no trans
  end;
end;

procedure TLogManager.ShutdownNotify;
begin
   //set this flag so that he stops sending status updates
   //while things are getting destroyed
   FThread.FShuttingDown := True;
end;

{ TBufferItem }

constructor TBufferItem.Create;
begin
   inherited;

end;

destructor TBufferItem.Destroy;
begin
   if Assigned( FDataObject ) then
      begin
         FDataObject.Free;
      end;
   inherited Destroy;
end;

function TLogManager.LogDebug(EventClass: TEventClass;
  EventString: String): Boolean;
var
   NewLogItem : TLogItem;
begin
     // create new log Item;
     try
        NewLogItem := LogItemFactory;
     except
        result := FALSE;
        exit;
     end;
     NewLogItem.EventString := EventString;
     NewLogItem.EventClass := EventClass;
     NewLogitem.EventLevel := elDebug;
     // insert item into log
     result := InsertLogEntry( NewLogItem );
end;

function TLogManager.RemoveOldLogFiles: Boolean;
var
   BackupFileList : TStringList;
   SearchRec : TSearchRec;
   FOldFileName : string;
   TodaysFile : string;
begin
   BackupFileList := TStringList.Create;
   BackupFileList.Sorted := TRUE;

   TodaysFile := GenerateLogFileName(nil);

   if( FindFirst( FLogPath + 'ECW*.log',  //no trans
         faAnyFile,
         SearchRec) = 0 )then
   begin
      FOldFileName := FLogPath + SearchRec.Name;
      if( FOldFileName <> TodaysFile ) then
      begin
         BackupFileList.Add( FOldFileName );
      end;
      while( FindNext( SearchRec ) = 0 ) do
      begin
         FOldFileName := FLogPath + SearchRec.Name;
         if( FOldFileName <> TodaysFile ) then
         begin
            BackupFileList.Add( FOldFileName );
         end;
      end;
   end;
   result := TRUE;
   while result AND (BackupFileList.Count > pred( FMaxNumberLogFiles ) )do
   begin
      if NOT( sysutils.DeleteFile( BackupFileList.Strings[0] ) ) then
      begin
         result := FALSE;
      end;
      BackupFileList.Delete( 0 );
   end;
   BackupFileList.Free;
   sysutils.FindClose( SearchRec ); //this frees memory allocated by FindFirst
end;

procedure TLogManager.RemoveStatusSubscriber(subscriber: TLogStatusEvent);
var
   i,j: integer;
   pCurrent,pTarget: TLogStatusEventReference;

begin
   i := 0;
   //the subscriber is a method pointer, which is actually two pointers,
   //the first to the code and the second to the data.
   //so, the first is the same for any subscriber of the same class,
   //and when deleting, we really want to be looking at the data pointer
   //which should be unique.
   //so, this record is used with an explicity typecast to get a reference to
   //the data pointer for the method...
   pTarget := TLogStatusEventReference(subscriber);
   while i < Length(StatusSubscribers) do
   begin
      pCurrent := TLogStatusEventReference(StatusSubscribers[i]);
      if pCurrent.pData = pTarget.pData then
      //if @StatusSubscribers[i] = @subscriber then
      begin
         for j := i to Length(StatusSubscribers)-2 do
         begin
            //shift items
            StatusSubscribers[j] := StatusSubscribers[j+1];
         end;
         SetLength(StatusSubscribers,Length(StatusSubscribers)-1);
         exit;
      end;
      inc(i);
   end;
end;

function TLogManager.GenerateLogFileName( LogItem : TLogItem ): string;
begin
   if Assigned( LogITem ) then
   begin
      result := FLogPath
         + 'ECW'  //no trans
         + FormatDateTime('YYYYMMDD', LogItem.TimeStamp)   //no trans
         + '.LOG';   //no trans
   end
   else
   begin // use the current date if no logitem is provided
      result := FLogPath
         + 'ECW'  //no trans
         + FormatDateTime('YYYYMMDD', Now)   //no trans
         + '.LOG';   //no trans
   end;
end;

function TLogManager.GetStatusSubscriberCount: integer;
begin
   result := Length(StatusSubscribers);
end;

function TLogManager.WriteLogEntryToDisplayBuffer(
  LogItem: TLogItem): Boolean;
var
  LogItem2: TLogItem;
begin
   // send event to display monitor
   // check display filters
   if IsItemInFilter( FDisplayFilterLevel, FDisplayFilter, LogItem ) then
   begin
      // put item in thread buffer
      FThreadBuffer.PushLogItem( LogItem );
   end
   else
   begin
      //if it is not going to the screen,
      //we are done with it
      LogItem.Free;
   end;

   result := TRUE;
end;

function TLogManager.WriteLogEntryToFile(LogItem: TLogItem): Boolean;
var
   tmpLogItem: TLogItem;
begin
   result := TRUE;
   //this section was added to be smart about debug logging
   //the goal is to log the last n of all messages, regardless of
   //filter settings, when an error occurs, to cut down on enormous log files.
   //The buffer is emptied when logged, so that a series of close errors do not
   //generate large dumps of the same data.
   //There are a couple of side effects:
   //this will cause the capacity of the FileBufferList
   //to grow potentially by the size of the dump buffer.
   //This will mess up customers with a buffer size of 1.
   //Also, this will caues messages to be inserted in non-chronological order
   //And there will be duplicates - however, the dump contents should be in order and
   //without duplicates.
   if FDumpBufferSize > 0 then
   begin
      //save all messages in rotary buffer for dumping.
      //if we are already in debug, this has no extra value
      if (FFileFilterLevel > elDebug) then
      begin
         //here we check if the new item should trigger a dump
         if LogItem.EventLevel = elError then
         begin
            //do a dump
            try
               tmpLogItem := LogItemFactory;
            except
               result := FALSE;
               exit;
            end;
            tmpLogItem.EventString := 'Dump Start'; //no trans
            tmpLogItem.EventClass := ecRuntime;
            tmpLogItem.EventLevel := elWarning;
            FFileBufferList.Add( tmpLogItem );


            //it will be logged below, so do nothing further
            //get out our saved messages
            while FDumpBufferList.Count > 0 do
            begin
               //move the saved items to be logged
               //and empty the dump buffer
               FFileBufferList.Add( FDumpBufferList[0] );
               FDumpBufferList.Delete(0);
            end;

            try
               tmpLogItem := LogItemFactory;
            except
               result := FALSE;
               exit;
            end;
            tmpLogItem.EventString := 'Dump End'; //no trans
            tmpLogItem.EventClass := ecRuntime;
            tmpLogItem.EventLevel := elWarning;
            FFileBufferList.Add( tmpLogItem );
            FPostErrorCountdown := FPostErrorMessages;
         end
         else
         begin
            //save it for possible use later
            while (FDumpBufferList.Count >= FDumpBufferList.Capacity) do
            begin
               TLogItem(FDumpBufferList[0]).Free;
               FDumpBufferList.Delete(0);
            end;
            FDumpBufferList.Add(LogItem.Duplicate);
         end;
      end;  //filtering some messages
   end;  //nonzero dump buffer
   //original processing from here on
   // check file filter options
   if IsItemInFilter( FFileFilterLevel, FFileFilter, LogItem ) then
   begin
      // put log entry into buffer
      FFileBufferList.Add( LogItem.Duplicate );
      // see if buffer is full - if the count equals the capacity, flush the buffer
      if FFileBufferList.Count >= FBufferDepth then
      begin
         result := FlushFileBuffer;
      end;
   end
   else
   begin
      if FPostErrorCountdown > 0 then
      begin
         Dec(FPostErrorCountdown);
      end;

   end;
end;

function TLogManager.IsItemInFilter(FilterLevel: TEventLevel;
  FilterClasses: TEventClassFilter; LogItem: TLogItem): boolean;
begin
  if( ( LogItem.EventClass in FilterClasses )
     AND ( LogItem.EventLevel >= FilterLevel ) )then
  begin
   result := TRUE;
  end
  else
  begin
   result := FALSE;
  end;
end;

function TLogManager.OpenFileForWriting(FName: String; var FStream : TFileStream): boolean;
begin
   result := CreateLogDirectoryIfNeeded;

   if result then
   begin
      // either create file if it doesn't exist or open it
      if not FileExists(DataFileName) then // if New data file then create it
      begin
         try
            // remove old files before creating new ones
            if NOT RemoveOldLogFiles then
            begin
               ShowMessage(Translate('Error removing old log files'));
            end;
            FStream := TFileStream.Create(DataFileName,
                        fmCreate OR fmShareDenyWrite);
         except
            ShowMessage( Format(Translate('Error Creating Log File: %s'),
                                 [DataFileName]) );
            result := FALSE;
         end;
      end
      else // just append to existing file
      begin
         try
            FStream := TFileStream.Create(DataFileName,fmOpenReadWrite
                        OR fmShareDenyWrite);
            FStream.seek(0, soFromEnd);
         except
               ShowMessage( Format(Translate('Error In Appending File %s'), [DataFileName]) );
               result := FALSE;
         end;
      end;
   end;

end;

function TLogManager.CreateLogDirectoryIfNeeded: Boolean;
begin
   result := TRUE;
   // Create Log Directory if it doesn't exist
//taj   if not DirectoryExists(FLogpath) then // create log directory
   if not SysUtils.DirectoryExists(FLogpath) then // create log directory
   begin
      if not CreateDir(FLogPath) then
      begin
         ShowMessage(Format(Translate('Error Creating Directory %s'), [FlogPath]) );
         result := FALSE;
      end;
   end;
end;


procedure TLogManager.PadStrings;
var
  MaxClass : integer; // maximum class value
  MaxLevel : integer; // maximum level value
  pti : PTypeInfo;
  ptd : PTypeData;
  IndexI, IndexJ, IndexK, charLen : integer;
  EnumString : string;
  transString: string; //this is to make the code more readable
begin
   //this procedure is intended to be called at startup and whenever
   //the language changes.

   // enter CS, because we do not want anyone logging something
   //while we are doing surgery on these string lists
   FLogCriticalSection.Enter;

   try
      // setup enumerated-to-string maps
      FEventClassMap.Clear;
      FUnPaddedClassMap.Clear;
      pti := TypeInfo( TEventClass );
      ptd := GetTypeData( pti );
      MaxClass := ptd^.MaxValue;
      //first we cycle through the strings to translate and add them to the list,
      //and count the characters to find the longest one
      INDEXJ := 0;
      for INDEXI := 0 to MaxClass do
      begin
         EnumString := GetEnumName(TypeInfo( TEventClass ), INDEXI ) ;
         //enumString is English, so standard byte Length should be OK
         transString := Translate(Copy( EnumString, 3, Length( EnumString ) - 2 ));
         FUnPaddedClassMap.Add( transString );
//taj         charLen := ByteToCharIndex(transString,Length(transString));
         charLen := ElementToCharIndex(transString,Length(transString));
         if(charLen > INDEXJ ) then INDEXJ := charLen;
      end;

      // pad all strings to make them the length of the longest one
      for INDEXI := 0 to MaxClass do
      begin
         FEventClassMap.Add( FUnPaddedClassMap[INDEXI] );
//taj         charLen := ByteToCharIndex(FUnPaddedClassMap[INDEXI],Length(FUnPaddedClassMap[INDEXI]));
         charLen := ElementToCharIndex(FUnPaddedClassMap[INDEXI],Length(FUnPaddedClassMap[INDEXI]));
         if(charLen < INDEXJ ) then
         begin
           for INDEXK := 1 to ( INDEXJ - charLen ) do
           begin
              FEventClassMap[INDEXI] := FEventClassMap[INDEXI] + ' '; //no trans
           end;
         end;
      end;

      FEventLevelMap.Clear;
      FUnPaddedLevelMap.Clear;
      pti := TypeInfo( TEventLevel );
      ptd := GetTypeData( pti );
      MaxLevel := ptd^.MaxValue;
      INDEXJ := 0;
      for INDEXI := 0 to MaxLevel do
      begin
        EnumString := GetEnumName( TypeInfo( TEventLevel ), INDEXI ) ;
        transString := Translate( Copy( EnumString, 3, Length( EnumString ) - 2 ));
        FUnPaddedLevelMap.Add( transString );
//taj        charLen := ByteToCharIndex( transString, Length(transString));
        charLen := ElementToCharIndex( transString, Length(transString));
        if(charLen > INDEXJ ) then INDEXJ := charLen;
      end;

      // pad all strings to make them the length of the longest one
      for INDEXI := 0 to MaxLevel do
      begin
        FEventLevelMap.Add( FUnPaddedLevelMap[INDEXI] );
//taj        charLen := ByteToCharIndex(FUnPaddedLevelMap[INDEXI],Length(FUnPaddedLevelMap[INDEXI]));
        charLen := ElementToCharIndex(FUnPaddedLevelMap[INDEXI],Length(FUnPaddedLevelMap[INDEXI]));
        if(charLen < INDEXJ ) then
        begin
          for INDEXK := 1 to ( INDEXJ - charLen ) do
          begin
               FEventLevelMap[INDEXI] := FEventLevelMap[INDEXI] + ' ';   //no trans
          end;
        end;
      end;
      SetLength(EnumString, 0);
      SetLength(transString, 0);
   finally
      // leave CS
      FLogCriticalSection.Leave;
   end;


end;

procedure TLogManager.ProcessMessages;
begin
   //The purpose it to prevent the process messages call from executing
   //within any thread but the main vcl thread.
   //this is intended to be a clearing house for all application.processmessages
   //calls
   //This is a convenient place to park it, because most of the units that call
   //the function would already have the log managerunit in the uses clause.

  // if (GetCurrentThreadID() = FMainVCLThreadID) then
   //begin
      //inc(FMessageDepth);
      Application.ProcessMessages;
      //TLogManager.Instance.LogWarning(ecRuntime,'message level='+IntToStr(FMessageDepth)); //no trans
      //dec(FMessageDepth)
   {
   end
   else
   begin
      LogDebug(ecRuntime,'ProcessMessages called from secondary thread'); //no trans
   end;
   }
end;

function TLogManager.FlushFileBuffer: boolean;
var
   DataRecFile : TFileStream;
   lastdatetime : TDateTime;
   currentlogitem : TLogItem;
   theRecordStr : string;
   theAnsiRecordStr : AnsiString;
begin
   lastdatetime := 0; // initialize datetime
   result := TRUE;
   DataRecFile := nil;
   while (FFileBufferList.Count > 0) AND result do
   begin
      // get next log item from list
      currentLogItem := TLogItem( FFileBufferList.Items[0] );
      // see if we need to generate a new file name and open it
      // this will help to make sure that log entries get put into the right
      // file around midnight, even with buffering enabled
      if Trunc( LastDateTime ) <> Trunc( currentLogItem.TimeStamp ) then
      begin
         // close the current file
         DataRecFile.Free;
         // synthesize log file name
         DataFileName := GenerateLogFileName( currentLogItem );
         // open file for writing
         if NOT OpenFileForWriting( DataFileName, DataRecFile ) then
         begin
            result := FALSE;
         end;
         LastDateTime := currentLogItem.TimeStamp; // save this datetime
      end;

      if result then
      begin
         // write log entry to stream
         try
            // get string to put in log
            theRecordStr := currentLogItem.EventSummary;
            // Convert to ascii for file output
//taj            theAnsiRecordStr := theRecordStr + newLine;
            theAnsiRecordStr := AnsiString(theRecordStr + newLine);
            // write the entry out
            DataRecFile.Write(Pointer(theAnsiRecordStr)^,Length(theAnsiRecordStr));
         except
            ShowMessage(Format(Translate('Error writing log event to file: %s'), [FDataFileName]) );
            result := FALSE;
         end;
      end;
      currentLogItem.Free; // free logItem
      FFileBufferList.Delete(0); // delete the entry from list
   end;
   //close the file and free stream
   DataRecFile.Free;
end;

function TLogManager.FlushLog: Boolean;
begin
   // enter CS
   FLogCriticalSection.Enter;
   try
      result := self.FlushFileBuffer;
   finally
      // leave CS
      FLogCriticalSection.Leave;
   end;

end;

{ TLogItemWithThreadID }

function TLogItemWithThreadID.Assign(Source: TLogItem): Boolean;
begin
   if Assigned( Source ) then
   begin
      result := inherited Assign(Source);
      if result and (Source is TLogItemWithThreadID) then
      begin
         FThreadID := TLogItemWithThreadID(Source).ThreadID;
      end;
   end
   else
   begin
      result := FALSE;
   end;
end;

constructor TLogItemWithThreadID.Create;
begin
   inherited;
   FThreadID := GetCurrentThreadId();
end;

function TLogItemWithThreadID.Duplicate: TLogItem;
begin
   result := TLogItemWithThreadID.Create;
   result.Assign( self );
end;

function TLogItemWithThreadID.GetBriefSummary: String;
begin
   result := inherited GetBriefSummary + ' ($' + Format('%x',[FThreadID] ) + ')';  //no trans
end;

function TLogItemWithThreadID.GetEventSummary: String;
begin
   result := inherited GetEventSummary + ' ($' + Format('%x',[FThreadID] ) + ')';  //no trans
end;

function TLogManager.LogItemFactory: TLogItem;
begin
   result := FLogItemClass.Create;
   result.BriefDateTimeFormatString := BriefDateTimeFormatString;
   result.BriefSummaryClassEnabled := BriefSummaryClassEnabled;
end;
{
Documentation|Log Triggers

Certain events, such as transmitting an FIS message,
can be triggered based on a certain message getting
logged.

It is a good idea to trigger events with debug messages
since these are not typically translated.

The log triggers for an FIS system are defined in the
Trigger Map.txt file.

Here is an example line from the Trigger Map.txt file:
 Production>MES,Production State = psStarting

In this example, when the message "Production State = psStarting"
is logged, then the FIS message called "Production" is sent
out the port named "MES".

It is also possible to use a wildcard on the trigger
portion, but these are computationally expensive and
should be used sparingly.

This is an example:
Report ID>Factory,*Upstream ID=

The "Report ID" FIS Message is sent out the port named "Factory"
whenever a message containing "Upstream ID=" is logged.
If the upstream ID variable is getting set to a scanned
barcode, then that portion of the log event would vary, so
it is necessary to use the wildcard in this case.



}

function TLogManager.AddLogTrigger(triggerID: integer;
  triggerString: string; callbackFunction: TLogTriggerEvent; caption: string; delayMilliseconds: integer=0): Boolean;
var
   tmpTrig: TTriggerRecord;
begin
   result := False;
   tmpTrig := TTriggerRecord.Create(triggerID,callbackFunction,caption);
   if (FTriggerList.AddTrigger(triggerString,tmpTrig) > -1) then
   begin
      result := True;
   end
   else
   begin
      TLogManager.Instance.LogError(ecStartup,'Failed to add log trigger: '+ Caption); //no trans
   end;
   if delayMilliseconds <> 0 then
   begin
      //we have a delay
      tmpTrig.triggerDelayMilliseconds := delayMilliseconds;
      tmpTrig.triggerDelayOn := True;
   end;
end;

{ TTriggerRecord }


{ TTriggerRecord }

constructor TTriggerRecord.Create(id: integer; callback: TLogTriggerEvent; cap: string);
begin
   triggerID := id;
   triggerCallback := callback;
   triggerCaption := cap;
   triggerDelayOn := False;
   triggerDelayMilliseconds := 0;
end;

function TLogManager.LogMessage(EventLevel: TEventLevel;
  EventClass: TEventClass; EventString: String): Boolean;
var
   NewLogItem : TLogItem;
begin

     // create new log Item;
     try
        NewLogItem := LogItemFactory;
     except
        result := FALSE;
        exit;
     end;
     NewLogItem.EventString := EventString;
     NewLogItem.EventClass := EventClass;
     NewLogitem.EventLevel := EventLevel;
     // insert item into log
     result := InsertLogEntry( NewLogItem );
end;
function TLogManager.LogStrings(EventLevel: TEventLevel;
  EventClass: TEventClass; EventStrings: TStrings; prefix: string): Boolean;
var
  i: Integer;
begin
   for i := 0 to EventStrings.Count - 1 do
   begin
      LogMessage(EventLevel,EventClass,prefix + EventStrings[i]);
   end;
   result := True;  //taj added
end;

procedure TLogManager.HandleTrigger(trig: TTriggerRecord);
var
   logItemTrigger: TLogItem;
begin
   trig.triggerCallback(trig.triggerID);
   //document it
   logItemTrigger := LogItemFactory;
   logItemTrigger.EventString := trig.triggerCaption;
   logItemTrigger.EventClass := ecRuntime;
   logItemTrigger.EventLevel := elDebug;
   WriteLogEntryToFile( logItemTrigger);
   logItemTrigger.Free;
end;

{ TTriggerStringList }

function TTriggerStringListOld.AddObject(const S: string;
  AObject: TObject): Integer;
var
   tmpStr: string;

begin
   result := -1;
   if length(s) > 0 then
   begin
      if s[1]='*' then //no trans
      begin
         if not Assigned(FPartialStrings) then
         begin
            FPartialStrings := TStringList.Create;
            FPartialStrings.Sorted := True;
            FPartialStrings.Duplicates := dupAccept;
         end;
         //we add this to both so that the indices match up
         tmpStr := Copy(S,2,length(S)-1);
         FPartialStrings.AddObject(tmpStr,AObject);
         result := inherited AddObject(S,AObject);
      end
      else
      begin
         result := inherited AddObject(S,AObject);
      end;
   end;
end;

destructor TTriggerStringListOld.Destroy;
begin
   if Assigned(FPartialStrings) then
   begin
      while FPartialStrings.Count>0 do
      begin
         FPartialStrings.Delete(0);
      end;
      FPartialStrings.Free;
   end;
  inherited;
end;

function TTriggerStringListOld.Find(const S: string; var Index: Integer): Boolean;
var
   i: integer;
begin
   result := inherited Find(S,Index);
   if not result then
   begin
      //exaxt match above overrides this partial match
      if Assigned(FPartialStrings) then
      begin
         //beware - this executes with every single log message...
         for i := 0 to (FPartialStrings.Count - 1) do
         begin
            if (Pos(FPartialStrings[i],S) > 0) then
            begin
               Index := i;
               result := True;
               //added for version 483
               //issue with partial match triggers not executing
               //if multiple triggers registered with the same log message
               break;
            end;
         end;
      end;

   end;
end;

function TTriggerStringList.AddTrigger(const S: string;
  AObject: TObject): Integer;
var
   tmpStr: string;
begin
   result := -1;
   if length(s) > 0 then
   begin
      if s[1]='*' then //no trans
      begin
         //we add this to the wildcard list without the asterisk
         tmpStr := Copy(S,2,length(S)-1);
         result := FWildcardStrings.AddObject(tmpStr,AObject);
      end
      else
      begin
         //just add it to the regular list
         result := FExactStrings.AddObject(S,AObject);
      end;
   end;
end;

constructor TTriggerStringList.Create;
begin
   inherited Create;

   FExactStrings := TStringList.Create;
   FExactStrings.Sorted := True;
   FExactStrings.Duplicates := dupAccept;

   FWildcardStrings := TStringList.Create;
   FWildcardStrings.Sorted := True;
   FWildcardStrings.Duplicates := dupAccept;



end;

destructor TTriggerStringList.Destroy;
begin
   while FWildcardStrings.Count>0 do
   begin
      FWildcardStrings.Objects[0].Free;
      FWildcardStrings.Delete(0);
   end;
   FWildcardStrings.Free;

   while FExactStrings.Count>0 do
   begin
      FExactStrings.Objects[0].Free;
      FExactStrings.Delete(0);
   end;
   FExactStrings.Free;


  inherited;
end;

function TTriggerStringList.Find(const S: string): TStringList;
var
   i,dummyInt: integer;
   firstMatchIndex: integer;
   testString: string;
begin
   //Version 571
   //This was modified to load a list of all unique
   //trigger objects that matched

   //The results are stored in the FoundTriggers property

   result := nil;
   //first clear the list
//   while FFoundTriggers.Count > 0 do FFoundTriggers.Delete(0);

   //look in the exact list first


//   tmpFound := FExactStrings.Find(S,i);
   if FExactStrings.Find(S,i) then
   begin
      //we have found a match
      result := TStringList.Create;
      result.Sorted := True;
      result.Duplicates := dupAccept;


      //add the address of the trigger object as a string
      //with the trigger object
      result.AddObject(IntToStr(integer(FExactStrings.Objects[i])),FExactStrings.Objects[i]);
      //now look for additional matches - there could be multiple triggers
      //for the same log message
      //store the index fo teh first match
      firstMatchIndex := i;
      i := i + 1;
      while  ( i < FExactStrings.Count)
      and    ( AnsiCompareText(FExactStrings[firstMatchIndex],FExactStrings[i])=0 ) do
      begin
         //we have another trigger for this string
         //for language independence, we have two strings in the list for the same trigger
         //one is translated, and one is not. However, the translated string might still be native
         //in which case we end up here
         //so convert the test item's address to a string and see if it is in our
         //list
         testString := IntToStr(Integer(FExactStrings.Objects[i])); //no trans
         if not (result.Find(testString,dummyInt)) then
         begin
            //OK, it is not in the list already, so go ahead and add it
            result.AddObject(testString,FExactStrings.Objects[i]);
         end;
         //and move on to the next item
         i := i + 1;
      end;
   end;

   //look in the wildcard list
   //this is different, , and expensive
   //since we need to search for every single wildcard in the log message
   for i := 0 to (FWildcardStrings.Count - 1) do
   begin
      if (Pos(FWildcardStrings[i],S) > 0) then
      begin
         //we have found a match
         if not Assigned(result) then
         begin
            result := TStringList.Create;
            result.Sorted := True;
            result.Duplicates := dupAccept;
         end;
         //like above, only add it if it is unique
         testString := IntToStr(Integer(FWildcardStrings.Objects[i])); //no trans
         if not (result.Find(testString,dummyInt)) then
         begin
            //OK, it is not in the list already, so go ahead and add it
            result.AddObject(testString,FWildcardStrings.Objects[i]);
         end;
      end;
   end;

end;


initialization

  // setup singelton
   SingletonInstance := TLogManager.SpecialCreate;

finalization
   // flush any remaining entries to disk;
   SingletonInstance.FlushLog;
   // free up maps
   while( FEventLevelMap.Count > 0 )do
      FEventLevelMap.Delete(0);
   FEventLevelMap.Free;
   while( FEventClassMap.Count > 0 )do
      FEventClassMap.Delete(0);
   FEventClassMap.Free;
//   SingletonCS.Free;
   // see if not freeing this removes some shutdown errors
   SingletonInstance.Free;
end.
