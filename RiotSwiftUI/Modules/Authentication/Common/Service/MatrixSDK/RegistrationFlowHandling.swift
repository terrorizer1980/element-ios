// 
// Copyright 2022 New Vector Ltd
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

@available(iOS 14.0, *)
/// A protocol with a default implementation that allows a coordinator to execute and handle registration flow steps.
protocol RegistrationFlowHandling {
    var authenticationService: AuthenticationService { get }
    var registrationWizard: RegistrationWizard { get }
    var completion: ((AuthenticationRegistrationCoordinatorResult) -> Void)? { get }
    
    /// Executes a registration step using the `RegistrationWizard` to complete any additional steps automatically.
    func executeRegistrationStep(step: @escaping (RegistrationWizard) async throws -> RegistrationResult) -> Task<Void, Error>
}

@available(iOS 14.0, *)
@MainActor extension RegistrationFlowHandling {
    func executeRegistrationStep(step: @escaping (RegistrationWizard) async throws -> RegistrationResult) -> Task<Void, Error> {
        return Task {
            do {
                let result = try await step(registrationWizard)
                
                guard !Task.isCancelled else { return }
                
                switch result {
                case .success(let mxSession):
                    completion?(.sessionCreated(session: mxSession, isAccountCreated: true))
                case .flowResponse(let flowResult):
                    await processFlowResponse(flowResult: flowResult)
                }
            } catch {
                #warning("Update the UI")
                print(error.localizedDescription)
            }
        }
    }
    
    /// Processes flow responses making sure the dummy stage is handled automatically when possible.
    func processFlowResponse(flowResult: FlowResult) async {
        // If dummy stage is mandatory, and password is already sent, do the dummy stage now
        if authenticationService.isRegistrationStarted && flowResult.missingStages.contains(where: { stage in
            guard case let FlowResult.Stage.dummy(isMandatory) = stage else { return false }
            return isMandatory
        }) {
            await handleRegisterDummy()
        } else {
            // Notify the user
            completion?(.flowResponse(flowResult))
        }
    }
    
    /// Handle the dummy stage of the flow.
    func handleRegisterDummy() async {
        let task = executeRegistrationStep { wizard in
            try await wizard.dummy()
        }
        
        #warning("Check if it is valid to await the result so this task becomes part of the last task.")
        let _ = await task.result
    }
}
