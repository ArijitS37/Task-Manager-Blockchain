// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

contract TaskManager {
    enum Priority { Low, Medium, High }

    struct Task {
        string description;
        address assignedTo;
        bool completed;
        uint dueDate; // Due date as a timestamp
        Priority priority; // Priority can be Low, Medium, or High
        uint createdAt; // Timestamp for task creation
    }

    mapping(uint => Task) private tasks;
    uint private taskCount; // Counter for task IDs
    uint private showCount; // Counter for active tasks

    address public owner;

    event TaskCreated(uint indexed taskId, string description, address assignedTo, uint dueDate, Priority priority);
    event TaskCompleted(uint indexed taskId);
    event TaskDeleted(uint indexed taskId);
    event TaskReassigned(uint indexed taskId, address indexed oldAssignee, address indexed newAssignee);
    event TaskUpdated(uint indexed taskId, string description, uint dueDate, Priority priority);
    event ContractPaused(address account);
    event ContractResumed(address account);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier validTaskId(uint _id) {
        require(_id <= taskCount && _id > 0, "Invalid task ID.");
        _;
    }

    modifier onlyAssignee(uint _id) {
        require(tasks[_id].assignedTo == msg.sender, "You're not assigned to this task.");
        _;
    }

    bool private paused = false;

    modifier whenNotPaused() {
        require(!paused, "Contract is paused.");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused.");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getTaskCount() public view returns (uint) {
        return showCount;
    }

    function createTask(string memory _description, uint _dueDate, Priority _priority) public whenNotPaused {
        taskCount++;
        showCount++;
        tasks[taskCount] = Task(_description, msg.sender, false, _dueDate, _priority, block.timestamp);
        emit TaskCreated(taskCount, _description, msg.sender, _dueDate, _priority);
    }

    function seeTasks(uint page, uint pageSize) public view returns (uint[] memory, string[] memory, bool[] memory, uint[] memory, Priority[] memory) {
        uint[] memory taskID = new uint[](showCount);
        string[] memory taskDesc = new string[](showCount);
        bool[] memory taskCompleted = new bool[](showCount);
        uint[] memory taskDueDate = new uint[](showCount);
        Priority[] memory taskPriority = new Priority[](showCount);

        uint validTaskCount = 0;
        for (uint i = 1; i <= taskCount; i++) {
            if (tasks[i].assignedTo == msg.sender) {
                taskID[validTaskCount] = i;
                taskDesc[validTaskCount] = tasks[i].description;
                taskCompleted[validTaskCount] = tasks[i].completed;
                taskDueDate[validTaskCount] = tasks[i].dueDate;
                taskPriority[validTaskCount] = tasks[i].priority;
                validTaskCount++;
            }
        }

        // Sorting tasks by due date
        for (uint i = 0; i < validTaskCount - 1; i++) {
            for (uint j = 0; j < validTaskCount - i - 1; j++) {
                if (taskDueDate[j] > taskDueDate[j + 1]) {
                    // Swap task ID
                    uint tempID = taskID[j];
                    taskID[j] = taskID[j + 1];
                    taskID[j + 1] = tempID;

                    // Swap task description
                    string memory tempDesc = taskDesc[j];
                    taskDesc[j] = taskDesc[j + 1];
                    taskDesc[j + 1] = tempDesc;

                    // Swap task completion status
                    bool tempCompleted = taskCompleted[j];
                    taskCompleted[j] = taskCompleted[j + 1];
                    taskCompleted[j + 1] = tempCompleted;

                    // Swap task due date
                    uint tempDueDate = taskDueDate[j];
                    taskDueDate[j] = taskDueDate[j + 1];
                    taskDueDate[j + 1] = tempDueDate;

                    // Swap task priority
                    Priority tempPriority = taskPriority[j];
                    taskPriority[j] = taskPriority[j + 1];
                    taskPriority[j + 1] = tempPriority;
                }
            }
        }

        // Pagination
        uint startIndex = page * pageSize;
        uint endIndex = startIndex + pageSize;
        if (endIndex > validTaskCount) {
            endIndex = validTaskCount;
        }

        uint size = endIndex - startIndex;
        uint[] memory pagedTaskID = new uint[](size);
        string[] memory pagedTaskDesc = new string[](size);
        bool[] memory pagedTaskCompleted = new bool[](size);
        uint[] memory pagedTaskDueDate = new uint[](size);
        Priority[] memory pagedTaskPriority = new Priority[](size);

        for (uint i = 0; i < size; i++) {
            pagedTaskID[i] = taskID[startIndex + i];
            pagedTaskDesc[i] = taskDesc[startIndex + i];
            pagedTaskCompleted[i] = taskCompleted[startIndex + i];
            pagedTaskDueDate[i] = taskDueDate[startIndex + i];
            pagedTaskPriority[i] = taskPriority[startIndex + i];
        }

        return (pagedTaskID, pagedTaskDesc, pagedTaskCompleted, pagedTaskDueDate, pagedTaskPriority);
    }

    function getTask(uint _id) public view validTaskId(_id) returns (string memory, address, bool, uint, Priority, uint) {
        Task storage task = tasks[_id];
        return (task.description, task.assignedTo, task.completed, task.dueDate, task.priority, task.createdAt);
    }

    function completeTask(uint _id) public validTaskId(_id) onlyAssignee(_id) whenNotPaused {
        Task storage task = tasks[_id];
        require(!task.completed, "Task is already completed.");
        task.completed = true;
        emit TaskCompleted(_id);
    }

    function deleteTask(uint _id) public validTaskId(_id) onlyAssignee(_id) whenNotPaused {
        delete tasks[_id];
        emit TaskDeleted(_id);
        showCount--;
    }

    function reassignTask(uint _id, address _newAssignee) public validTaskId(_id) onlyAssignee(_id) whenNotPaused {
        Task storage task = tasks[_id];
        address oldAssignee = task.assignedTo;
        task.assignedTo = _newAssignee;
        emit TaskReassigned(_id, oldAssignee, _newAssignee);
    }

    function updateTaskDescription(uint _id, string memory _newDescription) public validTaskId(_id) onlyAssignee(_id) whenNotPaused {
        Task storage task = tasks[_id];
        task.description = _newDescription;
        emit TaskUpdated(_id, _newDescription, task.dueDate, task.priority);
    }

    function updateTaskDueDate(uint _id, uint _newDueDate) public validTaskId(_id) onlyAssignee(_id) whenNotPaused {
        Task storage task = tasks[_id];
        task.dueDate = _newDueDate;
        emit TaskUpdated(_id, task.description, _newDueDate, task.priority);
    }

    function updateTaskPriority(uint _id, Priority _newPriority) public validTaskId(_id) onlyAssignee(_id) whenNotPaused {
        Task storage task = tasks[_id];
        task.priority = _newPriority;
        emit TaskUpdated(_id, task.description, task.dueDate, _newPriority);
    }

    function getTasksByPriority(Priority _priority) public view returns (uint[] memory) {
        uint[] memory result = new uint[](taskCount);
        uint count = 0;
        for (uint i = 1; i <= taskCount; i++) {
            if (tasks[i].priority == _priority) {
                result[count] = i;
                count++;
            }
        }
        uint[] memory finalResult = new uint[](count);
        for (uint j = 0; j < count; j++) {
            finalResult[j] = result[j];
        }
        return finalResult;
    }

    function getTasksByCompletion(bool _completed) public view returns (uint[] memory) {
        uint[] memory result = new uint[](taskCount);
        uint count = 0;
        for (uint i = 1; i <= taskCount; i++) {
            if (tasks[i].completed == _completed) {
                result[count] = i;
                count++;
            }
        }
        uint[] memory finalResult = new uint[](count);
        for (uint j = 0; j < count; j++) {
            finalResult[j] = result[j];
        }
        return finalResult;
    }

    function taskCountByAssignee(address _assignee) public view returns (uint) {
        uint count = 0;
        for (uint i = 1; i <= taskCount; i++) {
            if (tasks[i].assignedTo == _assignee) {
                count++;
            }
        }
        return count;
    }

    function pauseContract() public onlyOwner whenNotPaused {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function resumeContract() public onlyOwner whenPaused {
        paused = false;
        emit ContractResumed(msg.sender);
    }

    function isContractPaused() public view returns (bool) {
        return paused;
    }

    function ownerDeleteTask(uint _id) public validTaskId(_id) onlyOwner whenNotPaused {
        delete tasks[_id];
        emit TaskDeleted(_id);
        showCount--;
    }

    function getAllTasks() public view returns (
        uint[] memory taskIDs,
        string[] memory descriptions,
        address[] memory assignees,
        bool[] memory completions,
        uint[] memory dueDates,
        Priority[] memory priorities,
        uint[] memory creationDates
    ) {
        taskIDs = new uint[](taskCount);
        descriptions = new string[](taskCount);
        assignees = new address[](taskCount);
        completions = new bool[](taskCount);
        dueDates = new uint[](taskCount);
        priorities = new Priority[](taskCount);
        creationDates = new uint[](taskCount);

        for (uint i = 1; i <= taskCount; i++) {
            taskIDs[i-1] = i;
            descriptions[i-1] = tasks[i].description;
            assignees[i-1] = tasks[i].assignedTo;
            completions[i-1] = tasks[i].completed;
            dueDates[i-1] = tasks[i].dueDate;
            priorities[i-1] = tasks[i].priority;
            creationDates[i-1] = tasks[i].createdAt;
        }

        return (taskIDs, descriptions, assignees, completions, dueDates, priorities, creationDates);
    }
}

       
