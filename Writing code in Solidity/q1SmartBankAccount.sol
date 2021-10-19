//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

contract SmartBankAccount {
    uint256 totalContractBalance = 0;

    function getContractBalance() public view returns (uint256) {
        return totalContractBalance;
    }

    mapping(address => uint256) balances;
    mapping(address => uint256) depositTimestamps;

    function addBalance() public payable returns (bool) {
        balances[msg.sender] = msg.value;
        totalContractBalance += msg.value;
        depositTimestamps[msg.sender] = block.timestamp;

        return true;
    }

    function getBalance(address userAddress) public view returns (uint256) {
        uint256 principal = balances[userAddress];
        uint256 timeElapsed = block.timestamp - depositTimestamps[userAddress];
        return
            principal +
            uint256((principal * 7 * timeElapsed) / (100 * 365 * 24 * 60 * 60));
    }

    function withdraw() public payable returns (bool) {
        address payable withdrawTo = payable(msg.sender);
        uint256 amountToTransfer = getBalance(msg.sender);

        balances[msg.sender] = 0;
        totalContractBalance = totalContractBalance - amountToTransfer;
        (bool sent, ) = withdrawTo.call{value: amountToTransfer}("");
        require(sent, "transfer failed");

        return true;
    }

    function addMoneyToContract() public payable {
        totalContractBalance += msg.value;
    }

    receive() external payable {}
}
