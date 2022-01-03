// 
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

class LocationBeaconInfoBubbleCell: SizableBaseBubbleCell, BubbleCellReactionsDisplayable {
    
    private var locationView: RoomTimelineLocationView!
    
    override func render(_ cellData: MXKCellData!) {
        super.render(cellData)
        
        guard #available(iOS 14.0, *),
              let bubbleData = cellData as? RoomBubbleCellData,
              let event = bubbleData.events.last,
              event.eventType == __MXEventType.locationBeaconInfo,
              let content = event.content,
              let beaconInfo = content["m.beacon_info"] as? [String: Any],
              let room = bubbleData.mxSession.room(withRoomId: bubbleData.roomId)
        else {
            return
        }
        
        locationView.locationDescription = beaconInfo["description"] as? String
        
        room.state { [weak self] state in
            if let locationBeaconStateEvents = state?.stateEvents(with: .userLocationBeacon),
               let beaconEvent = locationBeaconStateEvents.last {
                self?.updateLocationWithEvent(beaconEvent)
            }
        }
        
        room.listen(toEventsOfTypes: [kMXEventTypeStringUserLocationBeacon]) { [weak self] event, direction, state in
            guard let event = event else {
                return
            }
            
            self?.updateLocationWithEvent(event)
        }
    }
    
    private func updateLocationWithEvent(_ event: MXEvent) {
        
        guard let locationDictionary = event.content[kMXMessageContentKeyExtensibleLocationMSC3488] as? [String: String],
              let locationContent = MXEventContentLocation(fromJSON: locationDictionary) else {
            return
        }
        
        let location = CLLocationCoordinate2D(latitude: locationContent.latitude, longitude: locationContent.longitude)
        
        locationView.displayLocation(location,
                                     userIdentifier: bubbleData.senderId,
                                     userDisplayName: bubbleData.senderDisplayName,
                                     userAvatarURLString: bubbleData.senderAvatarUrl,
                                     mediaManager: bubbleData.mxSession.mediaManager)
    }
    
    override func setupViews() {
        super.setupViews()
        
        bubbleCellContentView?.backgroundColor = .clear
        bubbleCellContentView?.showSenderInfo = true
        bubbleCellContentView?.showPaginationTitle = false
        
        guard #available(iOS 14.0, *),
              let contentView = bubbleCellContentView?.innerContentView else {
            return
        }
        
        locationView = RoomTimelineLocationView.loadFromNib()
        
        contentView.vc_addSubViewMatchingParent(locationView)
    }
}
