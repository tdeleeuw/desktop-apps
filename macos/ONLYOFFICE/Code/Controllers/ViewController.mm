/*
 * (c) Copyright Ascensio System SIA 2010-2016
 *
 * This program is a free software product. You can redistribute it and/or
 * modify it under the terms of the GNU Affero General Public License (AGPL)
 * version 3 as published by the Free Software Foundation. In accordance with
 * Section 7(a) of the GNU AGPL its Section 15 shall be amended to the effect
 * that Ascensio System SIA expressly excludes the warranty of non-infringement
 * of any third-party rights.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR  PURPOSE. For
 * details, see the GNU AGPL at: http://www.gnu.org/licenses/agpl-3.0.html
 *
 * You can contact Ascensio System SIA at Lubanas st. 125a-25, Riga, Latvia,
 * EU, LV-1021.
 *
 * The  interactive user interfaces in modified source and object code versions
 * of the Program must display Appropriate Legal Notices, as required under
 * Section 5 of the GNU AGPL version 3.
 *
 * Pursuant to Section 7(b) of the License you must retain the original Product
 * logo when distributing the program. Pursuant to Section 7(e) we decline to
 * grant you any rights under trademark law for use of our trademarks.
 *
 * All the Product's GUI elements, including illustrations and icon sets, as
 * well as technical writing content are licensed under the terms of the
 * Creative Commons Attribution-ShareAlike 4.0 International. See the License
 * terms at http://creativecommons.org/licenses/by-sa/4.0/legalcode
 *
*/

//
//  ViewController.m
//  ONLYOFFICE
//
//  Created by Alexander Yuzhin on 9/7/15.
//  Copyright (c) 2015 Ascensio System SIA. All rights reserved.
//

#import "ViewController.h"
#import "applicationmanager.h"
#import "mac_application.h"
#import "nsascprinter.h"
#import "ASCTabsControl.h"
#import "ASCTabView.h"
#import "ASCTitleWindowController.h"
#import "ASCHelper.h"
#import "ASCConstants.h"
#import "ASCUserInfoViewController.h"
#import "NSView+ASCView.h"
#import "NSString+OnlyOffice.h"
#import "AppDelegate.h"
#import "NSCefView.h"
#import "ASCEventsController.h"
#import "NSString+OnlyOffice.h"
#import "ASCDownloadController.h"
#import "NSTimer+Block.h"
#import "ASCSavePanelWithFormat.h"

#define rootTabId @"1CEF624D-9FF3-432B-9967-61361B5BFE8B"

@interface ViewController() <ASCTabsControlDelegate, ASCTitleBarControllerDelegate, ASCUserInfoViewControllerDelegate> {
    NSAscPrinterContext * m_pContext;
}
@property (weak) ASCTabsControl *tabsControl;
@property (nonatomic) NSCefView * cefStartPageView;
@property (weak) IBOutlet NSTabView *tabView;
@property (nonatomic) BOOL shouldTerminateApp;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWindowLoaded:)
                                                 name:ASCEventNameMainWindowLoaded
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFCreateTab:)
                                                 name:CEFEventNameCreateTab
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFLogout:)
                                                 name:CEFEventNameLogout
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFSave:)
                                                 name:CEFEventNameSave
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFOpenUrl:)
                                                 name:CEFEventNameOpenUrl
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFFullscreen:)
                                                 name:CEFEventNameFullscreen
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFKeyDown:)
                                                 name:CEFEventNameKeyboardDown
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFDownload:)
                                                 name:CEFEventNameDownload
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFStartSave:)
                                                 name:CEFEventNameStartSaveDialog
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFOnBeforePrintEnd:)
                                                 name:CEFEventNamePrintDialog
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFOnOpenLocalFile:)
                                                 name:CEFEventNameOpenLocalFile
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFSaveLocalFile:)
                                                 name:CEFEventNameSaveLocal
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCEFOpenLocalImage:)
                                                 name:CEFEventNameOpenImage
                                               object:nil];
    
    
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}


- (void)onWindowLoaded:(NSNotification *)notification {
    if (notification && notification.object) {
        ASCTitleWindowController *windowController = (ASCTitleWindowController *)notification.object;
        windowController.titlebarController.delegate = self;
        
        self.tabsControl = windowController.titlebarController.tabsControl;
        
        [self setupTabControl];
        [self createStartPage];
        [self loadStartPage];
        
        // Create CEF event listener
        [ASCEventsController sharedInstance];
    }
}

- (void)setupTabControl {
    self.tabsControl.minTabWidth = 48;
    self.tabsControl.maxTabWidth = 135;
    
    [self.tabsControl.multicastDelegate addDelegate:self];
}

- (void)createStartPage {
    NSInteger rootTabIndex = [self.tabView indexOfTabViewItemWithIdentifier:rootTabId];
    
    if (rootTabIndex != NSNotFound) {
        NSTabViewItem * tab = [self.tabView tabViewItemAtIndex:rootTabIndex];
        
        CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
        
        self.cefStartPageView = [[NSCefView alloc] initWithFrame:tab.view.frame];
        [self.cefStartPageView create:appManager withType:cvwtSimple];
        [tab.view addSubview:self.cefStartPageView];
        [self.cefStartPageView setupFillConstraints];
    }
}

- (void)loadStartPage {
    if (self.cefStartPageView ) {
        NSUserDefaults *preferences     = [NSUserDefaults standardUserDefaults];
        NSURLComponents *loginPage      = [NSURLComponents componentsWithString:[[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"login"]];
        NSURLQueryItem *countryCode     = [NSURLQueryItem queryItemWithName:@"lang" value:[[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] lowercaseString]];
        NSURLQueryItem *portalAddress   = [NSURLQueryItem queryItemWithName:@"portal" value:[preferences objectForKey:ASCUserSettingsNamePortalUrl]];
        loginPage.queryItems            = @[countryCode, portalAddress];
        loginPage.scheme                = NSURLFileScheme;
        
        [self.cefStartPageView loadWithUrl:[loginPage string]];
    }
}

#pragma mark -
#pragma mark Public

- (BOOL)shouldTerminateApplication {
    NSInteger unsaved = 0;
    
    for (ASCTabView * tab in self.tabsControl.tabs) {
        if (tab.changed) {
            unsaved++;
        }
    }
    
    if (unsaved > 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:NSLocalizedString(@"Review Changes...", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Save and Quit", nil)];
        [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"You have %ld ONLYOFFICE documents with unconfirmed changes. Do you want to review these changes before quitting?", nil), (long)unsaved]];
        [alert setInformativeText:NSLocalizedString(@"If you don't review your documents, all your changeses will be saved.", nil)];
        [alert setAlertStyle:NSInformationalAlertStyle];
        
        NSInteger result = [alert runModal];
        
        if (result == NSAlertFirstButtonReturn) {
            // "Review Changes..." clicked
            self.shouldTerminateApp = YES;
            
            NSArray * tabs = [NSArray arrayWithArray:self.tabsControl.tabs];
            for (ASCTabView * tab in tabs) {
                if (tab.changed) {
                    [self tabs:self.tabsControl willRemovedTab:tab];
                } else {
                    [self.tabsControl removeTab:tab];
                }
            }
        } else if (result == NSAlertSecondButtonReturn) {
            // "Cancel" clicked
            return NO;
        } else {
            // "Save and Quit" clicked
            self.shouldTerminateApp = YES;
            
            NSArray * tabs = [NSArray arrayWithArray:self.tabsControl.tabs];
            for (ASCTabView * tab in tabs) {
                if (tab.changed) {
                    NSTabViewItem * item = [self.tabView tabViewItemAtIndex:[self.tabView indexOfTabViewItemWithIdentifier:tab.uuid]];
                    NSCefView * cefView = nil;
                    
                    if (item) {
                        for (NSView * view in item.view.subviews) {
                            if ([view isKindOfClass:[NSCefView class]]) {
                                cefView = (NSCefView *)view;
                                break;
                            }
                        }
                    }
                    
                    if (cefView) {
                        NSEditorApi::CAscMenuEvent * pEvent = new NSEditorApi::CAscMenuEvent();
                        
                        pEvent->m_nType = ASC_MENU_EVENT_TYPE_CEF_SAVE;
                        [cefView apply:pEvent];
                    }
                } else {
                    [self.tabsControl removeTab:tab];
                }
            }
        }
        
        return NO;
    }
    
    return YES;
}

- (BOOL)shouldCloseMainWindow {
    if (self.tabsControl.tabs.count > 0) {
        ASCTabView * tab = [self.tabsControl selectedTab];
        
        if (tab) {
            if ([self tabs:self.tabsControl willRemovedTab:tab]) {
                [self.tabsControl removeTab:tab];
            }
            return NO;
        }
    }    
    return YES;
}

#pragma mark -
#pragma mark CEF events handlers

- (void)onCEFCreateTab:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params = (NSDictionary *)notification.userInfo;
        
        ASCTabView *tab = [[ASCTabView alloc] initWithFrame:CGRectZero];
        tab.title       = [NSString stringWithFormat:@"%@...", NSLocalizedString(@"Opening", nil)];
        tab.type        = ASCTabViewOpeningType;
        tab.params      = params;

        NSString * docUUID = params[@"hash"];
        
        if (docUUID && docUUID.length > 0) {
            ASCTabView * existTab = nil;
            
            for (ASCTabView * tab in self.tabsControl.tabs) {
                NSString * localUUID = tab.params[@"hash"];
                
                if ([docUUID isEqualToString:localUUID]) {
                    existTab = tab;
                    break;
                }
            }
            
            if (existTab) {
                [self.tabsControl selectTab:existTab];
            } else {
                [self.tabsControl addTab:tab selected:[params[@"active"] boolValue]];
            }
        } else {
            [self.tabsControl addTab:tab selected:[params[@"active"] boolValue]];
        }
    }
}

- (void)onCEFLogout:(NSNotification *)notification {
    [[ASCHelper localSettings] removeObjectForKey:ASCUserSettingsNameUserInfo];
    [self.tabsControl removeAllTabs];
    [self.tabView selectTabViewItemWithIdentifier:rootTabId];
    [self loadStartPage];
}

- (void)onCEFSave:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params = (NSDictionary *)notification.userInfo;
        NSString * viewId = params[@"viewId"];
        
        ASCTabView * tab = [self.tabsControl tabWithUUID:viewId];
        
        if (tab) {
            [self.tabsControl removeTab:tab];
        }
    }
}

- (void)onCEFSaveLocalFile:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params   = (NSDictionary *)notification.userInfo;
        NSString * directiry    = params[@"path"];
        NSString * viewId       = params[@"viewId"];
        NSArray * formats       = params[@"suppertFormats"];

        __block NSInteger fileType = [params[@"fileType"] intValue];
        
        ASCSavePanelWithFormat * savePanel = [ASCSavePanelWithFormat savePanel];
        
        savePanel.filters = formats;
        savePanel.filterType = fileType;
        
        if (!directiry || directiry.length < 1) {
            directiry = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        }
        
        savePanel.directoryURL = [NSURL URLWithString:directiry];
        savePanel.canCreateDirectories = YES;
        savePanel.nameFieldStringValue = [[directiry lastPathComponent] stringByDeletingPathExtension];
        
        [savePanel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSInteger result){
            [savePanel orderOut:self];

            NSEditorApi::CAscLocalSaveFileDialog * saveData = new NSEditorApi::CAscLocalSaveFileDialog();
            CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
            
            if (result == NSFileHandlingPanelOKButton) {
                NSString * extension = [ASCConstants ascFormatsInfo][@([savePanel filterType])][@"extension"];
                NSString * path = [NSString stringWithFormat:@"%@.%@", [[savePanel URL] path], extension];
                
                saveData->put_Path([path stdwstring]);
                saveData->put_Id([viewId intValue]);
                saveData->put_FileType((int)[savePanel filterType]);
            } else {
                saveData->put_Path(L"");
            }
            
            NSEditorApi::CAscMenuEvent* pEvent = new NSEditorApi::CAscMenuEvent(ASC_MENU_EVENT_TYPE_CEF_LOCALFILE_SAVE_PATH);
            pEvent->m_pData = saveData;
            
            appManager->Apply(pEvent);
        }];
    }
}

- (void)onCEFOpenUrl:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params = (NSDictionary *)notification.userInfo;
        NSString * linkUrl = params[@"url"];
        
        if (linkUrl && linkUrl.length > 0) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:linkUrl]];
        }
    }
}

- (void)onCEFFullscreen:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params = (NSDictionary *)notification.userInfo;
        
        BOOL isFullscreen = [params[@"fullscreen"] boolValue];
        NSTabViewItem * item = [self.tabView selectedTabViewItem];
        
        if (isFullscreen) {
            [item.view enterFullScreenMode:[NSScreen mainScreen] withOptions:nil];
        } else {
            [item.view exitFullScreenModeWithOptions:nil];
        }
    }
}

- (void)onCEFKeyDown:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params = (NSDictionary *)notification.userInfo;
        
        NSValue * eventData = params[@"data"];
        
        if (eventData) {
//            NSEditorApi::CAscKeyboardDown * pData = (NSEditorApi::CAscKeyboardDown *)[eventData pointerValue];
//
//            int     keyCode     = pData->get_KeyCode();
//            bool    isCtrl      = pData->get_IsCtrl();
//            BOOL    isCommand   = pData->get_IsCommandMac();
//
//            if(isCtrl && keyCode == kVK_ANSI_W) {
//                [self tabs:self.tabsControl willRemovedTab:[self.tabsControl selectedTab]];
//            }
        }
    }
}

- (void)onCEFDownload:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSDictionary * params = (NSDictionary *)notification.userInfo;
        CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
        NSValue * eventData = params[@"data"];
        
        if (nil == appManager || nil == eventData)
            return;
        
        NSEditorApi::CAscDownloadFileInfo * pDownloadFileInfo = (NSEditorApi::CAscDownloadFileInfo *)[eventData pointerValue];
        
        NSString * idx = [NSString stringWithFormat:@"%d", pDownloadFileInfo->get_Id()];
        
        if (pDownloadFileInfo->get_IsComplete()) {
            [[ASCDownloadController sharedInstance] removeDownload:idx];
        } else if (pDownloadFileInfo->get_IsCanceled()) {
            [[ASCDownloadController sharedInstance] removeDownload:idx];
        } else {
            id download = [[ASCDownloadController sharedInstance] downloadWithId:idx];
            
            if (nil == download) {
                NSString * path = [NSString stringWithstdwstring:pDownloadFileInfo->get_FilePath()];
                NSString * fileName = NSLocalizedString(@"Unconfirmed", nil);
                
                if (path && [path length] > 0) {
                    fileName = [path lastPathComponent];
                }
                
                [[ASCDownloadController sharedInstance] addDownload:idx fileName:fileName];
            }
            
            [[ASCDownloadController sharedInstance] updateDownload:idx data:eventData];
        }
    }
}

- (void)onCEFStartSave:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSString * fileName = notification.userInfo[@"fileName"];
        NSNumber * idx      = notification.userInfo[@"idx"];
        
        NSSavePanel * savePanel = [NSSavePanel savePanel];
//        [savePanel setDirectoryURL:[NSURL URLWithString:[NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject]]];
        if (fileName && fileName.length > 0) {
            [savePanel setAllowedFileTypes:@[fileName.pathExtension]];
            [savePanel setNameFieldStringValue:[fileName lastPathComponent]];
        }

        CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
        
        [savePanel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSInteger result){
            [savePanel orderOut:self];
           
            if (result == NSFileHandlingPanelOKButton) {
                appManager->EndSaveDialog([[[savePanel URL] path] stdwstring], [idx unsignedIntValue]);
            } else {
                appManager->EndSaveDialog(L"", [idx unsignedIntValue]);
            }
        }];
    }
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation success:(BOOL)success contextInfo:(void *)contextInfo {
    if (m_pContext) {
        m_pContext->EndPaint();
    }
}

- (void)onCEFOnBeforePrintEnd:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSNumber * viewId       = notification.userInfo[@"viewId"];
        NSNumber * pagesCount   = notification.userInfo[@"countPages"];
        
        CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
        
        if (appManager) {
            m_pContext = new NSAscPrinterContext(appManager);
            m_pContext->BeginPaint([viewId intValue], [pagesCount intValue], self, @selector(printOperationDidRun:success:contextInfo:));
        }
    }
}

- (void)onCEFOnOpenLocalFile:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSString * directory = notification.userInfo[@"directory"];
        
        if (!directory || directory.length < 1) {
            directory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        }
        
        NSOpenPanel * openPanel = [NSOpenPanel openPanel];
        NSMutableArray * filter = [NSMutableArray array];
        [filter addObjectsFromArray:[ASCConstants documents]];
        [filter addObjectsFromArray:[ASCConstants spreadsheets]];
        [filter addObjectsFromArray:[ASCConstants presentations]];
        
        openPanel.canChooseDirectories = NO;
        openPanel.allowsMultipleSelection = NO;
        openPanel.canChooseFiles = YES;
        openPanel.allowedFileTypes = filter;
        openPanel.directoryURL = [NSURL URLWithString:directory];

        [openPanel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSInteger result){
            [openPanel orderOut:self];
            
            if (result == NSFileHandlingPanelOKButton) {
                [[NSNotificationCenter defaultCenter] postNotificationName:CEFEventNameCreateTab
                                                                    object:nil
                                                                  userInfo:@{
                                                                             @"action"  : @(ASCTabActionOpenLocalFile),
                                                                             @"file"    : [[openPanel URL] path],
                                                                             @"active"  : @(YES)
                                                                             }];
            }
        }];
    }
}

- (void)onCEFOpenLocalImage:(NSNotification *)notification {
    if (notification && notification.userInfo) {
        NSString * directory = notification.userInfo[@"path"];
        NSInteger fileId = [notification.userInfo[@"fileId"] intValue];
        
        if (!directory || directory.length < 1) {
            directory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        }
        
        NSOpenPanel * openPanel = [NSOpenPanel openPanel];

        openPanel.canChooseDirectories = NO;
        openPanel.allowsMultipleSelection = NO;
        openPanel.canChooseFiles = YES;
        openPanel.allowedFileTypes = [ASCConstants images];
        openPanel.directoryURL = [NSURL URLWithString:directory];
        
        [openPanel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSInteger result){
            [openPanel orderOut:self];
            
            if (result == NSFileHandlingPanelOKButton) {
                CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
                
                NSEditorApi::CAscLocalOpenFileDialog * imageInfo = new NSEditorApi::CAscLocalOpenFileDialog();
                imageInfo->put_Id((int)fileId);
                imageInfo->put_Path([[[openPanel URL] path] stdwstring]);
                
                NSEditorApi::CAscMenuEvent* pEvent = new NSEditorApi::CAscMenuEvent(ASC_MENU_EVENT_TYPE_CEF_LOCALFILE_ADDIMAGE);
                pEvent->m_pData = imageInfo;
                
                appManager->Apply(pEvent);
            }
        }];
    }
}


#pragma mark -
#pragma mark ASCTabsControl Delegate

- (void)tabs:(ASCTabsControl *)control didSelectTab:(ASCTabView *)tab {
    if (tab) {
        [self.tabView selectTabViewItemWithIdentifier:tab.uuid];
    }
}

- (void)tabs:(ASCTabsControl *)control didAddTab:(ASCTabView *)tab {
    if (tab.params) {
        CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
        NSCefView * cefView = [[NSCefView alloc] initWithFrame:CGRectZero];
        
        ASCTabActionType action = (ASCTabActionType)[tab.params[@"action"] intValue];
        
        if (action == ASCTabActionOpenPortal) {
            [cefView create:appManager withType:cvwtSimple];
        } else {
            [cefView create:appManager withType:cvwtEditor];
        }
        
        switch (action) {
            case ASCTabActionOpenPortal: {
                tab.type  = ASCTabViewPortal;
                tab.title = [[NSURL URLWithString:tab.params[@"url"]] host];
            }
            case ASCTabActionOpenUrl: {
                [cefView loadWithUrl:tab.params[@"url"]];
                break;
            }
                
            case ASCTabActionCreateLocalFile: {
                int docType = [tab.params[@"type"] intValue];
                NSString * docName = [NSLocalizedString(@"New Document", nil) stringByAppendingString:@".docx"];
                
                switch (docType) {
                    case 1: docName = [NSLocalizedString(@"New Spreadsheet", nil) stringByAppendingString:@".xlsx"];    break;
                    case 2: docName = [NSLocalizedString(@"New Presentation", nil) stringByAppendingString:@".pptx"];   break;
                }
                
                [cefView createFileWithName:docName type:docType];
                break;
            }
                
            case ASCTabActionOpenLocalFile: {
                NSString * filePath = tab.params[@"file"];
                
                if (filePath) {
                    int fileFormatType = CCefViewEditor::GetFileFormat([filePath stdwstring]);
                    [cefView openFileWithName:filePath type:fileFormatType];
                }
                
                break;
            }
            case ASCTabActionOpenLocalRecoverFile: {
                NSInteger docId = [tab.params[@"fileId"] intValue];
                [cefView openRecoverFileWithId:docId];
                break;
            }
            case ASCTabActionOpenLocalRecentFile: {
                NSInteger docId = [tab.params[@"fileId"] intValue];
                [cefView openRecentFileWithId:docId];
                break;
            }

            default:
                break;
        }
        
        
        tab.uuid = [NSString stringWithFormat:@"%ld", (long)cefView.uuid];
        
        NSTabViewItem * item = [[NSTabViewItem alloc] initWithIdentifier:tab.uuid];
        item.label = tab.title;
        [self.tabView addTabViewItem:item];
        [item.view addSubview:cefView];
        [cefView setupFillConstraints];
    }
}

- (BOOL)tabs:(ASCTabsControl *)control willRemovedTab:(ASCTabView *)tab {
    if (tab && tab.changed) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:NSLocalizedString(@"Yes", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"No", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Do you want to save the changes made to the document \"%@\"?", nil), tab.title]];
        [alert setInformativeText:NSLocalizedString(@"Your changes will be lost if you don’t save them.", nil)];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSAlertFirstButtonReturn) {
                NSTabViewItem * item = [self.tabView tabViewItemAtIndex:[self.tabView indexOfTabViewItemWithIdentifier:tab.uuid]];
                NSCefView * cefView = nil;
                
                if (item) {
                    for (NSView * view in item.view.subviews) {
                        if ([view isKindOfClass:[NSCefView class]]) {
                            cefView = (NSCefView *)view;
                            break;
                        }
                    }
                }
                
                if (cefView) {
                    NSEditorApi::CAscMenuEvent* pEvent = new NSEditorApi::CAscMenuEvent();
                    
                    pEvent->m_nType = ASC_MENU_EVENT_TYPE_CEF_SAVE;
                    [cefView apply:pEvent];
                }
            } else if (returnCode == NSAlertSecondButtonReturn) {
                [control removeTab:tab];
            } else if (returnCode == NSAlertThirdButtonReturn) {
                self.shouldTerminateApp = NO;
            }
        }];
        
        return NO;
    }

    return YES;
}

- (void)tabs:(ASCTabsControl *)control didRemovedTab:(ASCTabView *)tab {
    CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
    appManager->DestroyCefView([tab.uuid intValue]);

    NSTabViewItem * item = [self.tabView tabViewItemAtIndex:[self.tabView indexOfTabViewItemWithIdentifier:tab.uuid]];
    NSCefView * cefView = nil;
    
    if (item) {
        for (NSView * view in item.view.subviews) {
            if ([view isKindOfClass:[NSCefView class]]) {
                cefView = (NSCefView *)view;
                break;
            }
        }
        
        if (cefView) {
            [cefView internalClean];
        }
    }
    
    [self.tabView removeTabViewItem:[self.tabView tabViewItemAtIndex:[self.tabView indexOfTabViewItemWithIdentifier:tab.uuid]]];
    
    if (self.shouldTerminateApp && self.tabsControl.tabs.count < 1) {
        [NSApp terminate:nil];
    }
}

- (void)tabs:(ASCTabsControl *)control didReorderTab:(ASCTabView *)tab {
    //
}

#pragma mark -
#pragma mark ASCTitleBarController Delegate

- (void)onOnlyofficeButton:(id)sender {
    [self.tabView selectTabViewItemWithIdentifier:rootTabId];
    [self.tabsControl selectTab:nil];
}

- (void)onShowUserInfoController:(NSViewController *)controller {
    ASCUserInfoViewController *userInfoController = (ASCUserInfoViewController *)controller;
    userInfoController.delegate = self;
}

#pragma mark -
#pragma mark ASCUserInfoViewController Delegate

- (void)onLogoutButton:(ASCUserInfoViewController *)controller {
    CAscApplicationManager * appManager = [NSAscApplicationWorker getAppManager];
    NSDictionary * userInfo = [[ASCHelper localSettings] valueForKey:ASCUserSettingsNameUserInfo];
    
    if (userInfo) {
        NSString * portal = userInfo[@"portal"];
        
        if (portal) {
            appManager->Logout([portal stdwstring]);
        }
    }
}

#pragma mark -
#pragma mark Debug

//- (IBAction)onAddTab:(id)sender {
//    ASCTabView *tab = [[ASCTabView alloc] initWithFrame:CGRectZero];
//    tab.title = [NSString stringWithFormat:@"Tab %lu", (unsigned long)rand() % 10000];
//    [self.tabsControl addTab:tab];
//}
//
//- (IBAction)onRemoveTab:(id)sender {
//    [self.tabsControl removeTab:[[self.tabsControl tabs] firstObject]];
//}
@end
