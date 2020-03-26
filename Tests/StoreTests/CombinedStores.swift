import XCTest
import Combine
@testable import Store

struct Root {
  struct Todo {
    var name: String = "Untitled"
    var description: String = "N/A"
    var done: Bool = false
  }
  struct Note {
    var author: String = "Nobody"
    var text: String = ""
    var upvotes: Int = 0
  }
  var note: Note = Note()
  var todo: Todo = Todo()
  // List example with transient stores.
  var list: [Todo] = []
}

class RootStore: Store<Root> {
  // Children test.
  lazy var todoStore = makeChildStore(keyPath: \.todo)
  lazy var noteStore = makeChildStore(keyPath: \.note)

  // List and transient store tests.
  lazy var listStore = makeChildStore(keyPath: \.list)
}

// MARK: Combined Stores

extension Root.Todo {
  struct Action_MarkAsDone: ActionProtocol {
    func reduce(context: TransactionContext<Store<Root.Todo>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { $0.done = true }
    }
  }
}

extension Root.Note {
  struct Action_IncreaseUpvotes: ActionProtocol {
    func reduce(context: TransactionContext<Store<Root.Note>, Self>) {
      defer { context.fulfill() }
      context.reduceModel { $0.upvotes += 1 }
    }
  }
}

// MARK: List and Transient Stores.

extension Root.Todo {
  struct Action_ListCreateNew: ActionProtocol {
    let name: String
    let description: String
    func reduce(context: TransactionContext<Store<Array<Root.Todo>>, Self>) {
      defer { context.fulfill() }
      let new = Root.Todo(name: name, description: description)
      context.reduceModel {
        $0.append(new)
      }
    }
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
final class CombinedStoreTests: XCTestCase {
  
  var sink: AnyCancellable?

  // MARK: Combined Stores
  
  func testChildStoreChangesRootStoreValue() {
    let rootStore = RootStore(model: Root())
    XCTAssertFalse(rootStore.model.todo.done)
    XCTAssertFalse(rootStore.todoStore.model.done)
    rootStore.todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(rootStore.todoStore.model.done)
    XCTAssertTrue(rootStore.model.todo.done)
  }
  
  func testChildStoreChangesTriggersRootObserver() {
    let observerExpectation = expectation(description: "Observer called.")
    let rootStore = RootStore(model: Root())
    sink = rootStore.objectWillChange.sink {
      XCTAssertTrue(rootStore.model.todo.done)
      XCTAssertTrue(rootStore.todoStore.model.done)
      observerExpectation.fulfill()      
    }
    rootStore.todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(rootStore.todoStore.model.done)
    XCTAssertTrue(rootStore.model.todo.done)
    waitForExpectations(timeout: 1)
  }
  
  func testListAndTransientStores() {
    let rootStore = RootStore(model: Root())
    rootStore.listStore.run(
      action: Root.Todo.Action_ListCreateNew(name: "New", description: "New"),
      mode: .sync)
    XCTAssertTrue(rootStore.listStore.model.count == 1)
    XCTAssertTrue(rootStore.listStore.model[0].name == "New")
    XCTAssertTrue(rootStore.listStore.model[0].description == "New")
    XCTAssertTrue(rootStore.listStore.model[0].done == false)
    XCTAssertTrue(rootStore.model.list.count == 1)
    XCTAssertTrue(rootStore.model.list[0].name == "New")
    XCTAssertTrue(rootStore.model.list[0].description == "New")
    XCTAssertTrue(rootStore.model.list[0].done == false)
    
    let todoStore: Store<Root.Todo> = rootStore.listStore.makeChildStore(keyPath: \.[0])
    todoStore.run(action: Root.Todo.Action_MarkAsDone(), mode: .sync)
    XCTAssertTrue(todoStore.model.name == "New")
    XCTAssertTrue(todoStore.model.description == "New")
    XCTAssertTrue(todoStore.model.done == true)
    XCTAssertTrue(rootStore.listStore.model.count == 1)
    XCTAssertTrue(rootStore.listStore.model[0].name == "New")
    XCTAssertTrue(rootStore.listStore.model[0].description == "New")
    XCTAssertTrue(rootStore.listStore.model[0].done == true)
    XCTAssertTrue(rootStore.model.list.count == 1)
    XCTAssertTrue(rootStore.model.list[0].name == "New")
    XCTAssertTrue(rootStore.model.list[0].description == "New")
    XCTAssertTrue(rootStore.model.list[0].done == true)
  }
}

