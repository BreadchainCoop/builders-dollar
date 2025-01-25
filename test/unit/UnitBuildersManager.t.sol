// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

contract BuildersManager {
  function test_InitializeWhenPassingValidSettings() external {
    // it sets the settings
    // it deploys the contract
  }

  function test_InitializeWhenPassingInvalidSettings() external {
    // it reverts with SettingsNotSet
  }

  function test_OP_SCHEMA_638WhenCalled() external {
    // it returns the OP_SCHEMA_638
  }

  function test_TOKENWhenCalled() external {
    // it returns the token address
  }

  function test_EASWhenCalled() external {
    // it returns the EAS address
  }

  function test_OptimismFoundationAttesterWhenTheAttesterIsAnOptimismFoundationAttester() external {
    // it returns true
  }

  function test_OptimismFoundationAttesterWhenTheAttesterIsNotAnOptimismFoundationAttester() external {
    // it returns false
  }

  function test_EligibleVoterWhenTheVoterIsEligibleAndVouched() external {
    // it returns true
  }

  function test_EligibleVoterWhenTheVoterIsNotEligibleOrVouched() external {
    // it returns false
  }

  function test_EligibleProjectWhenTheProjectIsEligible() external {
    // it returns the project
  }

  function test_EligibleProjectWhenTheProjectIsNotEligible() external {
    // it returns the project
  }

  function test_ProjectToExpiryWhenTheProjectIsEligible() external {
    // it returns the expiry
  }

  function test_ProjectToExpiryWhenTheProjectIsNotEligible() external {
    // it returns the expiry
  }

  function test_ProjectToVouchesWhenTheProjectIsEligible() external {
    // it returns the vouches
  }

  function test_ProjectToVouchesWhenTheProjectIsNotEligible() external {
    // it returns the vouches
  }

  function test_VoterToProjectVouchWhenTheVoterHasVouchedForTheProject() external {
    // it returns true
  }

  function test_VoterToProjectVouchWhenTheVoterHasNotVouchedForTheProject() external {
    // it returns false
  }

  function test_SettingsReturnsTheSettings() external {
    // it returns the settings
  }

  function test_CurrentProjectsWhenThereAreProjects() external {
    // it returns the current projects
  }

  function test_CurrentProjectsWhenThereAreNoProjects() external {
    // it returns an empty array
  }

  function test_OptimismFoundationAttestersWhenThereAreAttesters() external {
    // it returns the optimism foundation attesters
  }

  function test_OptimismFoundationAttestersWhenThereAreNoAttesters() external {
    // it returns an empty array
  }

  function test_VouchWhenPassingValidProjectAttestation() external {
    // it sets the project as eligible
    // it emits ProjectValidated
    // it increments the project's vouches
  }

  function test_VouchWhenPassingProjectAttestationThatIsAlreadyEligible() external {
    // it increments the project's vouches
  }

  function test_VouchWhenPassingInvalidProjectAttestation() external {
    // it reverts with InvalidProjectAttestation
  }

  function test_VouchWhenPassingValidProjectAttestationAndValidIdentityAttestation() external {
    // it sets the project as eligible
    // it sets the identity as eligible
    // it emits ProjectValidated
    // it emits VoterValidated
    // it increments the project's vouches
  }

  function test_VouchWhenPassingInvalidIdentityAttestation() external {
    // it reverts with InvalidIdentityAttestation
  }

  function test_ValidateOptimismVoterWhenPassingValidIdentityAttestation() external {
    // it sets the identity as eligible
    // it emits VoterValidated
    // it returns true
  }

  function test_ValidateOptimismVoterWhenPassingIdentityAttestationThatIsAlreadyEligible() external {
    // it reverts with AlreadyVerified
  }

  function test_ValidateOptimismVoterWhenPassingInvalidIdentityAttestation() external {
    // it returns false
  }

  function test_DistributeYieldWhenTheCycleIsReady() external {
    // it distributes the yield
    // it emits YieldDistributed
  }

  function test_DistributeYieldWhenThereAreNoProjects() external {
    // it reverts with YieldNoProjects
  }

  function test_DistributeYieldWhenTheCycleIsNotReady() external {
    // it reverts with CycleNotReady
  }

  function test_ModifyParamsWhenPassingValidParamAndValue() external {
    // it modifies the param
    // it emits ParamsModified
  }

  function test_ModifyParamsWhenPassingInvalidParamOrValue() external {
    // it reverts with InvalidParam
  }

  function test_UpdateOpFoundationAttesterWhenPassingValidAttesterAndStatus() external {
    // it updates the attester
    // it emits OpFoundationAttesterUpdated
  }

  function test_UpdateOpFoundationAttesterWhenPassingInvalidAttesterOrStatus() external {
    // it reverts with InvalidAttester
  }

  function test_BatchUpdateOpFoundationAttestersWhenPassingValidAttestersAndStatuses() external {
    // it updates the attesters
    // it emits OpFoundationAttestersUpdated
  }

  function test_BatchUpdateOpFoundationAttestersWhenPassingInvalidAttestersOrStatuses() external {
    // it reverts with InvalidAttesters
  }
}
