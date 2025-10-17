//
//  CarinaProgressView.swift
//  Project Iris Watch App
//
//  Created by 雷美淳 on 2024/2/6.
//

import Cepheus
import RadarKitCore
import SwiftUI
import UIKit

struct CarinaDetailView: View {
  var id: String
  @State var projectManager: RKCFeedbackManager = RKCFeedbackManager(projectName: "Project Iris")
  @State var feedbackBasics: RKCFeedback?
  @State var feedbackContent: RKCFormattedFile?
  @State var feedbackReplies: [RKCFormattedFile] = []
  
  @State var feedbackState = "UNMARKED"
  @State var titleIsExpaneded = false
  @State var loading = true
  var dateFormatter = DateFormatter()
  var body: some View {
    NavigationStack {
      if loading {
        ProgressView()
      } else if feedbackContent != nil {
        List {
          Section {
            Text(feedbackBasics!.title)
              .bold()
              .lineLimit(titleIsExpaneded ? nil : 2)
              .onTapGesture {
                titleIsExpaneded.toggle()
              }
            NavigationLink(destination: {
              CarinaStateDescriptionView(feedbackState: feedbackState)
            }, label: {
              HStack {
                Circle()
                  .frame(width: 10)
                  .foregroundStyle(newCarinaStateColors[feedbackState] ?? .secondary)
                  .padding(.horizontal, 7)
                Text(newCarinaStateLocalizedKeys[feedbackState] ?? "Carina.info.load")
                Spacer()
              }
            })
            if feedbackContent!.Content != nil && feedbackContent!.Content != "" {
              NavigationLink(destination: {
                List {
                  Text(feedbackContent!.Content!)
                }
              }, label: {
                Text(feedbackContent!.Content!)
                  .lineLimit(3)
              })
            }
          }
          Section {
            NavigationLink(destination: {
              CarinaRepliesView(projectManager: projectManager, id: id)
            }, label: {
              HStack {
                Label("Carina.reply.\(feedbackReplies.count)", systemImage: "arrowshape.turn.up.left")
                Spacer()
                Image(systemName: "chevron.forward")
                  .foregroundStyle(.secondary)
              }
            })
          }
          Section {
            //MARK: Time
            if feedbackContent!.Time != nil {
              HStack {
                Image(systemName: "clock")
                Text(dateFormatter.string(from: Date(timeIntervalSince1970: (Double(feedbackContent!.Time!) ?? 0))))
                Spacer()
              }
            }
            //MARK: Versions
            if feedbackContent!.OS != nil {
              HStack {
                Image(systemName: "applewatch.side.right")
                Text("watchOS \(feedbackContent!.OS!)")
                Spacer()
              }
            }
            if feedbackContent!.Version != nil {
              HStack {
                Image(systemName: "app.badge")
                Text("Iris \(feedbackContent!.Version!)")
                Spacer()
              }
            }
            //MARK: Links
            if feedbackContent!.AttachedLinks != nil {
              if stringToStringArray(feedbackContent!.AttachedLinks!)!.count > 1 {
                NavigationLink(destination: {
                  List {
                    ForEach(stringToStringArray(feedbackContent!.AttachedLinks!)!, id: \.self) { link in
                      Button(action: {
                        searchButtonAction(isPrivateModeOn: false, searchField: link, isCookiesAllowed: true, searchEngine: "")
                      }, label: {
                        Text(link)
                      })
                    }
                  }
                  .navigationTitle("Carina.attached-links")
                }, label: {
                  HStack {
                    Image(systemName: "link")
                    Text("Carina.new.attachments.links.\(stringToStringArray(feedbackContent!.AttachedLinks!)!.count)")
                    Spacer()
                    Image(systemName: "chevron.forward")
                      .foregroundStyle(.secondary)
                  }
                })
              } else {
                Button(action: {
                  searchButtonAction(isPrivateModeOn: false, searchField: stringToStringArray(feedbackContent!.AttachedLinks!)![0], isCookiesAllowed: true, searchEngine: "")
                }, label: {
                  HStack {
                    Image(systemName: "link")
                    Text(stringToStringArray(feedbackContent!.AttachedLinks!)![0])
                    Spacer()
                  }
                })
              }
            }
            //MARK: Attachments
            if contentHasAttachments(feedbackContent!) {
              HStack {
                Image(systemName: "paperclip")
                Text("Carina.has-attachments")
                Spacer()
              }
            }
          }
        }
      } else {
        ProgressView()
      }
    }
    .navigationTitle("#" + id)
    .onAppear {
      Task {
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        feedbackBasics = await projectManager.getFeedback(byId: id)
        loading = false
        if feedbackBasics != nil {
          var feedback = RKCFileFormatter(for: feedbackBasics!)
          feedbackContent = feedback.content()
          feedbackReplies = feedback.replies().filtered()
        }
        feedbackState = feedbackBasics?.state.rawValue ?? "UNMARKED"
      }
    }
  }
}

struct CarinaRepliesView: View {
  var projectManager: RKCFeedbackManager
  var id: String
  @State var replies: [RKCFormattedFile] = []
  @State var feedbackIsClosed = false
  @State var repliesExpanding: [Int: Bool] = [:]
  @State var dateFormatter = DateFormatter()
  @State var isReady = false
  @State var replySheetIsDisplaying = false
  @State var listShouldUpdate = false
//  @State var loading = true
  var body: some View {
    NavigationStack {
      if isReady {
        if replies.count > 0 {
          List {
            if #unavailable(watchOS 10) {
              Section(content: {
                Button(action: {
                  replySheetIsDisplaying = true
                }, label: {
                  Label("Carina.reply.send.title", systemImage: "paperplane")
                })
              }, footer: {
                if feedbackIsClosed {
                  Text("Carina.reply.closed.description")
                }
              })
              .disabled(feedbackIsClosed)
            }
            ForEach(0..<replies.count, id: \.self) { replyIndex in
              Section(content: {
                if repliesExpanding[replyIndex] ?? true {
                    //MARK: State
                  if replies[replyIndex].State != nil {
                    NavigationLink(destination: {
                      CarinaStateDescriptionView(feedbackState: replies[replyIndex].State!)
                    }, label: {
                      HStack {
                        Image(systemName: newCarinaStateIcons[replies[replyIndex].State!] ?? "ellipsis")
                        Text(newCarinaStateLocalizedKeys[replies[replyIndex].State!] ?? "Carina.info.load")
                        Spacer()
                        Circle()
                          .frame(width: 10)
                          .foregroundStyle(newCarinaStateColors[replies[replyIndex].State!] ?? .secondary)
                          .padding(.horizontal, 7)
                      }
                    })
                  }
                    //MARK: Content
                  if replies[replyIndex].Content != nil {
                    Label(replies[replyIndex].Content!, systemImage: "text.bubble")
                  }
                    //MARK: Links
                  if replies[replyIndex].AttachedLinks != nil {
                    if stringToStringArray(replies[replyIndex].AttachedLinks!)!.count > 1 {
                      NavigationLink(destination: {
                        List {
                          ForEach(stringToStringArray(replies[replyIndex].AttachedLinks!)!, id: \.self) { link in
                            Button(action: {
                              searchButtonAction(isPrivateModeOn: false, searchField: link, isCookiesAllowed: true, searchEngine: "")
                            }, label: {
                              Text(link)
                            })
                          }
                        }
                        .navigationTitle("Carina.attached-links")
                      }, label: {
                        HStack {
                          Label("Carina.new.attachments.links.\(stringToStringArray(replies[replyIndex].AttachedLinks!)!.count)", systemImage: "link")
                          Spacer()
                          Image(systemName: "chevron.forward")
                            .foregroundStyle(.secondary)
                        }
                      })
                    } else {
                      Button(action: {
                        searchButtonAction(isPrivateModeOn: false, searchField: stringToStringArray(replies[replyIndex].AttachedLinks!)![0], isCookiesAllowed: true, searchEngine: "")
                      }, label: {
                        Label(stringToStringArray(replies[replyIndex].AttachedLinks!)![0], systemImage: "link")
                      })
                    }
                  }
                    //MARK: Attachments
                  if contentHasAttachments(replies[replyIndex]) {
                    Label("Carina.has-attachments", systemImage: "paperclip")
                  }
                }
              }, header: {
                HStack {
                  Text(replies[replyIndex].Sender ?? String(localized: "Carina.reply.sender.unknown"))
                  Spacer()
                  Image(systemName: "chevron.forward")
                    .rotationEffect(Angle(degrees: repliesExpanding[replyIndex] ?? true ? 90 : 0))
                    .overlay {
                      Rectangle()
                        .opacity(0.02)
                        .onTapGesture {
                          withAnimation {
                            repliesExpanding[replyIndex]!.toggle()
                          }
                        }
                    }
                }
                .font(.caption)
                .fontWeight(.medium)
              }, footer: {
                if replies[replyIndex].Time != nil {
                  Text(dateFormatter.string(from: Date(timeIntervalSince1970: (Double(replies[replyIndex].Time!) ?? 0))))
                }
              })
            }
            .onAppear {
              for index in 0..<replies.count {
                repliesExpanding.updateValue(true, forKey: index)
              }
            }
          }
        } else {
          if isReady {
            if #available(watchOS 10, *) {
              ContentUnavailableView {
                Label("Carina.reply.none", systemImage: "bubble.and.pencil")
              } description: {
                Text("Carina.reply.none.description")
              }
            } else {
              List {
                if #unavailable(watchOS 10) {
                  Button(action: {
                    replySheetIsDisplaying = true
                  }, label: {
                    Label("Carina.reply.send.title", systemImage: "paperplane")
                  })
                }
                Text("Carina.reply.none")
                  .bold()
                Text("Carina.reply.none.description")
              }
              .foregroundStyle(.secondary)
            }
          } else {
            ProgressView()
          }
        }
      } else {
        ProgressView()
      }
    }
    .toolbar {
      if #available(watchOS 10, *) {
        ToolbarItemGroup(placement: .bottomBar, content: {
          HStack {
            Spacer()
            Button(action: {
              replySheetIsDisplaying = true
            }, label: {
              Image(systemName: "paperplane")
                .foregroundStyle(feedbackIsClosed ? .secondary : .primary)
            })
//            .disabled(feedbackIsClosed)
          }
        })
      }
    }
    .navigationTitle("Carina.reply")
    .onAppear {
      listInit()
    }
    .onChange(of: listShouldUpdate, perform: { value in
      if listShouldUpdate {
        listInit()
      }
      listShouldUpdate = false
    })
    .sheet(isPresented: $replySheetIsDisplaying, content: {
      CarinaSendReplyView(projectManager: projectManager, id: id, listShouldUpdate: $listShouldUpdate)
    })
  }
  func listInit() {
    isReady = false
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    Task {
      var feedbackBasics = await projectManager.getFeedback(byId: id)
      if feedbackBasics != nil {
        var feedback = RKCFileFormatter(for: feedbackBasics!)
        replies = feedback.replies().reversed().filtered()
        feedbackIsClosed = feedbackBasics!.shouldDisableUserReply
      }
    }
//    for index in 0..<replies.count {
//      repliesExpanding.updateValue(true, forKey: index)
//    }
    isReady = true
  }
}

struct CarinaSendReplyView: View {
  var projectManager: RKCFeedbackManager
  var id: String
  @Binding var listShouldUpdate: Bool
  @State var isReady = false
  @State var feedbackIsClosed = false
  @State var replyContent = ""
  
  @State var sendDeviceInfos: Bool = false
  @State var sendSettingsValues: Bool = false
  @State var sendRegionInfos: Bool = false
  @State var sendBookmarkFiles: Bool = false
  @State var sendHistoryFiles: Bool = false
  @State var attachedLinks: [String] = []
  var body: some View {
    NavigationStack {
      if isReady {
        if !feedbackIsClosed {
          List {
            Section(content: {
              CepheusKeyboard(input: $replyContent, prompt: "Carina.reply.send.content")
              NavigationLink(destination: {
                CarinaAttachmentsView(sendDeviceInfos: $sendDeviceInfos, sendSettingsValues: $sendSettingsValues, sendRegionInfos: $sendRegionInfos, sendBookmarkFiles: $sendBookmarkFiles, sendHistoryFiles: $sendHistoryFiles, attachedLinks: $attachedLinks, alertIsShowingAfterTogglingOff: false)
                if #unavailable(watchOS 10) {
                  DismissButton(action: {
                    Task {
                      var sent = await projectManager.replyFeedback(toId: id, withContent: """
            \(replyContent)
            \(generateAttachmentDatas(sendDeviceInfos: sendDeviceInfos, sendSettingsValues: sendSettingsValues, sendRegionInfos: sendRegionInfos, sendBookmarkFiles: sendBookmarkFiles, sendHistoryFiles: sendHistoryFiles, attachedLinks: attachedLinks))
            """, bySender: "Iris \(currentIrisVersion)")
                      showTip(sent ? "Carina.reply.succeed" : "Carina.reply.failure", symbol: sent ? "paperplane" : "xmark")
                      listShouldUpdate = true
                    }
                  }, label: {
                    Label("Carina.reply.send", systemImage: "paperplane")
                  })
                  .disabled(replyContent.isEmpty && countAttachmentNumbers(attachedLinks: attachedLinks, sendDeviceInfos, sendRegionInfos, sendHistoryFiles, sendBookmarkFiles, sendSettingsValues) == 0)
                }
              }, label: {
                HStack {
                  Label("Carina.reply.send.attachments", systemImage: "paperclip")
                  Spacer()
                  Text("\(countAttachmentNumbers(attachedLinks: attachedLinks, sendDeviceInfos, sendRegionInfos, sendHistoryFiles, sendBookmarkFiles, sendSettingsValues))")
                    .foregroundStyle(.secondary)
                  Image(systemName: "chevron.forward")
                    .foregroundStyle(.secondary)
                }
              })
            }, footer: {
              Text("Carina.reply.send.sign.\("Iris " + currentIrisVersion)")
            })
          }
          .navigationTitle("Carina.reply.send")
          .toolbar {
            if #available(watchOS 10, *) {
              ToolbarItem(placement: .topBarTrailing, content: {
                DismissButton(action: {
                  Task {
                    var sent = await projectManager.replyFeedback(toId: id, withContent: """
          \(replyContent)
          \(generateAttachmentDatas(sendDeviceInfos: sendDeviceInfos, sendSettingsValues: sendSettingsValues, sendRegionInfos: sendRegionInfos, sendBookmarkFiles: sendBookmarkFiles, sendHistoryFiles: sendHistoryFiles, attachedLinks: attachedLinks))
          """, bySender: "Iris \(currentIrisVersion)")
                    showTip(sent ? "Carina.reply.succeed" : "Carina.reply.failure", symbol: sent ? "paperplane" : "xmark")
                    listShouldUpdate = sent
                  }
                }, label: {
                  Image(systemName: "paperplane")
                })
                .disabled(replyContent.isEmpty && countAttachmentNumbers(attachedLinks: attachedLinks, sendDeviceInfos, sendRegionInfos, sendHistoryFiles, sendBookmarkFiles, sendSettingsValues) == 0)
              })
            }
          }
        } else {
          if #available(watchOS 10, *) {
            ContentUnavailableView {
              Label("Carina.reply.closed", systemImage: "xmark.bin")
            } description: {
              Text("Carina.reply.closed.description")
            }
          } else {
            Text("Carina.reply.closed.description")
              .bold()
              .foregroundStyle(.secondary)
          }
        }
      } else {
        ProgressView()
      }
    }
    .onAppear {
      isReady = false
      Task {
        var feedbackBasics = await projectManager.getFeedback(byId: id)
        if feedbackBasics != nil {
          feedbackIsClosed = feedbackBasics!.shouldDisableUserReply
        }
      }
      isReady = true
    }
  }
}

struct CarinaAttachmentsView: View {
  @Binding var sendDeviceInfos: Bool
  @Binding var sendSettingsValues: Bool
  @Binding var sendRegionInfos: Bool
  @Binding var sendBookmarkFiles: Bool
  @Binding var sendHistoryFiles: Bool
  @Binding var attachedLinks: [String]
  
  var alertIsShowingAfterTogglingOff = true
  @State var showSettingsDisablingAlert = false
  @State var attachedLinksPickerSheetIsShowing = false
  @State var attachedBookmarksPickerSheetIsShowing = false
  @State var attachedHistoryPickerSheetIsShowing = false
  @State var selectedGroup = -1
  @State var selectedBookmark = -1
  @State var historyLink = ""
  @State var historyID = -1
  @State var manualAttachingLink = ""
  
  @AppStorage("lockHistory") var lockHistory = false
  @AppStorage("lockBookmarks") var lockBookmarks = false
  //  @State var lastHistoryID = UserDefaults.standard.integer(forKey: "lastHistoryID")
  var body: some View {
    List {
      Section(content: {
        CarinaAttachmentUnit(isOn: $sendSettingsValues, label: {
          Text("Carinaa.attachments.data.settings-info")
        })
        .onChange(of: sendSettingsValues, perform: { value in
          if alertIsShowingAfterTogglingOff {
            showSettingsDisablingAlert = !sendSettingsValues
          }
        })
        .alert("Carina.attachments.data.settings-info.alert.title", isPresented: $showSettingsDisablingAlert, actions: {
          Button(role: .cancel, action: {
            sendSettingsValues = true
          }, label: {
            Text("Carina.attachments.data.settings-info.alert.cancel")
          })
          Button(role: .destructive, action: {
            sendSettingsValues = false
          }, label: {
            Text("Carina.attachments.data.settings-info.alert.confirm")
          })
          .foregroundStyle(.red)
        }, message: {
          Text("Carina.attachments.data.settings-info.alert.message")
        })
        CarinaAttachmentUnit(isOn: $sendDeviceInfos, label: {
          Text("Carinaa.attachments.data.device-info")
        })
        CarinaAttachmentUnit(isOn: $sendRegionInfos, label: {
          Text("Carinaa.attachments.data.region-info")
        })
      }, header: {
        Text("Carina.attachments.data")
      }, footer: {
        Text("Carina.attachments.data.footer")
      })
      Section(content: {
        CarinaAttachmentUnit(isOn: $sendBookmarkFiles, label: {
          Text("Carinaa.attachments.files.bookmarks")
        })
        CarinaAttachmentUnit(isOn: $sendHistoryFiles, label: {
          Text("Carinaa.attachments.files.history")
        })
      }, header: {
        Text("Carina.attachments.files")
      }, footer: {
        Text("Carina.attachments.files.footer")
      })
      Section(content: {
        Button(action: {
          attachedLinksPickerSheetIsShowing = true
        }, label: {
          Label("Carina.attachments.links.add", systemImage: "plus")
        })
        .sheet(isPresented: $attachedLinksPickerSheetIsShowing, content: {
          NavigationStack {
            List {
              if #available(watchOS 10, *) {
                NavigationLink(destination: {
                  PasscodeView(destination: {
                    BookmarkPickerView(editorSheetIsDisaplying: $attachedBookmarksPickerSheetIsShowing, seletedGroup: $selectedGroup, selectedBookmark: $selectedBookmark, groupIndexEqualingGoal: -1, bookmarkIndexEqualingGoal: -1, action: {
                      attachedLinks.append(getBookmarkLibrary()[selectedGroup].3[selectedBookmark].3)
                    })
                  }, title: "Bookmark.select", directPass: !lockBookmarks)
                }, label: {
                  HStack {
                    Label("Carina.attachments.links.bookmarks", systemImage: "bookmark")
                    Spacer()
                    LockIndicator(destination: "bookmarks")
                  }
                })
              }
              NavigationLink(destination: {
                PasscodeView(destination: {
                  HistoryPickerView(pickerSheetIsDisplaying: $attachedHistoryPickerSheetIsShowing, historyLink: $historyLink, historyID: $historyID, acceptNonLinkHistory: false, action: {
                    attachedLinks.append(historyLink)})
                }, title: "History.select", directPass: !lockHistory)
              }, label: {
                HStack {
                  Label("Carina.attachments.links.history", systemImage: "clock")
                  Spacer()
                  LockIndicator(destination: "history")
                }
              })
              NavigationLink(destination: {
                List {
                  TextField("Carina.attachments.links.manual.prompt", text: $manualAttachingLink)
                  if !manualAttachingLink.isURL() {
                    Label("Carina.attachments.links.manual.invalid", systemImage: "exclamationmark.circle")
                      .foregroundStyle(.red)
                  }
                  DismissButton(action: {
                    attachedLinks.append(manualAttachingLink)
                  }, label: {
                    Label("Carina.attachments.links.manual.attach", systemImage: "plus")
                  })
                  .disabled(!manualAttachingLink.isURL())
                }
                .navigationTitle("Carina.attachments.links.manual")
              }, label: {
                Label("Carina.attachments.links.manual", systemImage: "character.cursor.ibeam")
              })
            }
            .navigationTitle("Carina.attachments.links.add")
            .onAppear {
              selectedGroup = -1
              selectedBookmark = -1
              historyLink = ""
              historyID = -1
              manualAttachingLink = ""
            }
          }
        })
        if !attachedLinks.isEmpty {
          ForEach(0..<attachedLinks.count, id: \.self) { linkIndex in
            Text(attachedLinks[linkIndex])
          }
          .onDelete(perform: { removingIndex in
            attachedLinks.remove(atOffsets: removingIndex)
          })
        }
      }, header: {
        Text("Carina.attachments.links")
      }, footer: {
        Text("Carina.attachments.links.footer")
      })
    }
    .navigationTitle("Carina.attachments")
  }
}

struct CarinaAttachmentUnit<L: View>: View {
  @Binding var isOn: Bool
  var label: () -> L
  var body: some View {
    Button(action: {
      isOn.toggle()
    }, label: {
      HStack {
        label()
        Spacer()
        if isOn {
          Image(systemName: "checkmark")
        }
      }
    })
  }
}

func countAttachmentNumbers(attachedLinks: [String], _ parameters: Bool...) -> Int {
  var total = 0
  for i in 0..<parameters.count {
    if parameters[i] {
      total += 1
    }
  }
  total += attachedLinks.count
  return total
}

func generateAttachmentDatas(sendDeviceInfos: Bool, sendSettingsValues: Bool, sendRegionInfos: Bool, sendBookmarkFiles: Bool, sendHistoryFiles: Bool, attachedLinks: [String]) -> String {
  var package = ""
  
  //MARK: Settings
  var settingsValues = ""
  settingsValues = getSettingsForAppdiagnose { data in
    data.removeValue(forKey: "correctPasscode")
  } ?? "nil"
  if sendSettingsValues {
    package.append("""

Settings：\(settingsValues)
""")
  }
  
  //MARK: Device
  if sendDeviceInfos {
    package.append("""

DeviceSize：\(watchSize)
""")
  }
  
  //MARK: Region
  let languageCode = Locale.current.language.languageCode
  let countryCode = Locale.current.region!.identifier
  let timeZone = getCurrentTimezone()
  if sendRegionInfos {
    package.append("""

Language：\(languageCode!)
Region：\(countryCode)
TimeZone：\(timeZone)
""")
  }
  
  //MARK: Links
  if !attachedLinks.isEmpty {
    package.append("""

AttachedLinks：\(attachedLinks)
""")
  }
  
  //MARK: Bookmarks
  if sendBookmarkFiles {
    package.append("""

BookmarksFile：\(readPlainTextFile("BookmarkLibrary.txt").replacingOccurrences(of: "\n", with: "\\n"))
""")
  }
  
  //MARK: History
  if sendHistoryFiles {
    package.append("""

HistoryFile：\(readPlainTextFile("historyData.txt").replacingOccurrences(of: "\n", with: "\\n"))
""")
  }
  
  return package
}


//func getAccessibilityInfos() -> String {
//  let assistiveTouch = UIAccessibilityIsAssistiveTouchRunning()
//  return ""
//}

func stringToStringArray(_ input: String) -> [String]? {
  var source = input
  var output: [String]
  if source.hasPrefix("[") && source.hasSuffix("]") {
    source.removeFirst()
    source.removeLast()
    output = source.components(separatedBy: ", ")
    for i in 0..<output.count {
        output[i] = String(output[i].dropFirst().dropLast())
    }
    return output
  } else {
    return nil
  }
}

func contentHasAttachments(_ content: RKCFormattedFile) -> Bool {
  return content.Language != nil || content.DeviceSize != nil || content.HistoryFile != nil || content.Settings != nil
}


struct CarinaStateDescriptionView: View {
  var feedbackState: String
  var body: some View {
    List {
      HStack {
        Image(systemName: newCarinaStateIcons[feedbackState] ?? "ellipsis")
        Text(newCarinaStateLocalizedKeys[feedbackState] ?? "Carina.info.load")
        Spacer()
        Circle()
          .frame(width: 10)
          .foregroundStyle(newCarinaStateColors[feedbackState] ?? .secondary)
          .padding(.trailing, 7)
      }
      .bold()
      Text(newCarinaStateLocalizedDescriptions[feedbackState] ?? "Carina.info.load")
    }
    .navigationTitle(newCarinaStateLocalizedKeys[feedbackState] ?? "Carina.info.load")
  }
}
