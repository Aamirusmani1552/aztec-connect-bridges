// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IStabilityPool {
    function provideToSP(uint256 _amount, address _frontEndTag) external;

    function withdrawFromSP(uint256 _amount) external;

    function getCompoundedLUSDDeposit(address _depositor) external view returns (uint256);
}
