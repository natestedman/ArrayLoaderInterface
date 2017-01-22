// ArrayLoaderInterface
// Written in 2016 by Nate Stedman <nate@natestedman.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright and
// related and neighboring rights to this software to the public domain worldwide.
// This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along with
// this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import ArrayLoader
import LayoutModules
import ReactiveSwift
import UIKit
import enum Result.NoError

// MARK: - Controller

/// A controller that integrates a collection view and an array loader.
///
/// This is not a view controller class - instead, it should be used as part of view controller classes.
public final class ArrayLoaderCollectionViewController
    <ValueDisplay: ArrayLoaderValueDisplaying,
     ErrorDisplay: ArrayLoaderErrorDisplaying,
     ActivityDisplay,
     CompletedDisplay>
     where ValueDisplay: UICollectionViewCell,
           ErrorDisplay: UICollectionViewCell,
           ActivityDisplay: UICollectionViewCell,
           CompletedDisplay: UICollectionViewCell
{
    // MARK: - Initialization

    /**
    Initializes an array loader collection view controller.

    - parameter activityItemSize:   The size for activity cells - only one dimension is used at a time, based on the
                                    current major layout axis. The default value of this parameter is `(44, 44)`.
    - parameter errorItemSize:      The row height for error cells - only one dimension is used at a time, based on the
                                    current major layout axis. The default value of this parameter is `(44, 44)`.
    - parameter completedItemSize:  The row height for the completed footer cell - only one dimension is used at a
                                    time, based on the current major layout axis. The default value of this parameter is
                                    `(0, 0)`.
    - parameter customHeaderView:   An optional custom header view, displayed after activity content for the next page.
    - parameter valuesLayoutModule: The layout module to use for the section displaying the array loader's values.
    */
    public init(activityItemSize: CGSize = CGSize(width: 44, height: 44),
                errorItemSize: CGSize = CGSize(width: 44, height: 44),
                completedItemSize: CGSize = CGSize.zero,
                customHeaderView: UIView? = nil,
                valuesLayoutModule: LayoutModule)
    {
        self.arrayLoaderState = arrayLoader.value.state.value
        self.customHeaderView = customHeaderView

        // create collection view layout
        self.layout = LayoutModulesCollectionViewLayout(majorAxis: .vertical, moduleForSection: { section in
            LayoutModule.moduleForSection(
                Section(rawValue: section)!,
                activityItemSize: activityItemSize,
                errorItemSize: errorItemSize,
                completedItemSize: completedItemSize,
                customHeaderView: customHeaderView,
                valuesLayoutModule: valuesLayoutModule
            )
        })

        // create collection view with layout
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        self.collectionView = collectionView

        collectionView.registerCellClass(CustomHeaderViewCollectionViewCell.self)
        collectionView.registerCellClass(ValueDisplay.self)
        collectionView.registerCellClass(ErrorDisplay.self)
        collectionView.registerCellClass(ActivityDisplay.self)
        collectionView.registerCellClass(CompletedDisplay.self)

        // create helper object to implement collection view
        let helper = CollectionViewHelper(parent: self)
        collectionView.dataSource = helper
        collectionView.delegate = helper
        self.helper = helper

        // watch state and reload collection view
        arrayLoader.producer
            .flatMap(.latest, transform: { $0.events.producer })
            .skip(first: 1)
            .observe(on: UIScheduler())
            .flatMap(.concat, transform: { [weak self] event in
                self?.updateCollectionViewProducer(for: event) ?? SignalProducer.empty
            })
            .start()

        // automatically load the first page of new array loaders
        arrayLoader.signal.observeValues({ loader in
            if loader.elements.count == 0 && loader.nextPageState.isHasMore
            {
                loader.loadNextPage()
            }
        })

        // add and remove the refresh control
        let arrayLoaderState = arrayLoader.producer.flatMap(.latest, transform: { $0.state.producer })

        refreshControl <~ SignalProducer.combineLatest(arrayLoaderState, previousPageLoadingMode.producer)
            .map({ state, mode in
                (state.previousPageState == .hasMore && mode.isLoadPreviousPage) || mode.isReplace ? mode.title : nil
            })
            .skipRepeats(==)
            .observe(on: UIScheduler())
            .map({ optionalTitle -> UIRefreshControl? in
                optionalTitle.map({ title in
                    let control = UIRefreshControl()
                    control.attributedTitle = NSAttributedString(string: title, attributes: nil)
                    return control
                })
            })

        refreshControl.producer.combinePrevious(nil).startWithValues({ [weak self] previous, current in
            previous?.removeFromSuperview()

            if let control = current, let strong = self
            {
                control.addTarget(
                    strong.helper,
                    action: #selector(Helper.refreshAction),
                    for: .valueChanged
                )

                strong.collectionView.addSubview(control)
            }
        })

        // update the refresh control's loading state
        let loadingPreviousPage = arrayLoader.producer.flatMap(.latest, transform: { loader in
            SignalProducer(value: loader.previousPageState.isLoading).concat(
                loader.events.map({ event -> Bool? in
                    switch event
                    {
                    case .previousPageLoading:
                        return true
                    case .previousPageLoaded, .previousPageFailed:
                        return false
                    default:
                        return nil
                    }
                }).skipNil()
            )
        }).skipRepeats()

        SignalProducer.combineLatest(refreshControl.producer, loadingPreviousPage)
            .startWithValues({ optionalControl, loadingPreviousPage in
                guard let control = optionalControl else { return }

                if loadingPreviousPage && !control.isRefreshing
                {
                    control.beginRefreshing()
                }
                else if !loadingPreviousPage && control.isRefreshing
                {
                    control.endRefreshing()
                }
            })
    }

    // MARK: - Collection View

    /// The collection view managed by the controller.
    public let collectionView: UICollectionView

    /// A typealias for `helper`.
    fileprivate typealias Helper = CollectionViewHelper<ValueDisplay, ErrorDisplay, ActivityDisplay, CompletedDisplay>

    /// The helper object for this controller.
    fileprivate var helper: Helper?

    /// The collection view layout.
    fileprivate let layout: LayoutModulesCollectionViewLayout

    /// The current major axis for the collection view layout.
    public var majorAxis: Axis
    {
        get { return layout.majorAxis }
        set { layout.majorAxis = newValue }
    }

    // MARK: - Array Loader

    /// The array loader being used by the controller.
    public let arrayLoader = MutableProperty(
        StaticArrayLoader<ValueDisplay.Value>.empty.promoteErrors(ErrorDisplay.Error.self)
    )

    /// The current array loader display state, which may lag behind the actual state - updates are concatenated by
    /// ReactiveCocoa.
    var arrayLoaderState: LoaderState<ValueDisplay.Value, ErrorDisplay.Error>

    // MARK: - Internal Interface Elements

    /// If provided, this view will be visible below the previous page content.
    let customHeaderView: UIView?

    /// The current refresh control, if applicable.
    let refreshControl = MutableProperty(UIRefreshControl?.none)

    // MARK: - State

    /// The interface's behavior with respect to loading the previous page - a client might want to limit this by
    /// only allowing the previous page to load if the first page has already loaded. The default value is `disallow`.
    public let previousPageLoadingMode = MutableProperty(
        PreviousPageLoadingMode<ValueDisplay.Value, ErrorDisplay.Error>.disallow
    )

    // MARK: - Callbacks

    /// A callback sent when the view will display a cell.
    public var willDisplayCell: ((_ cell: UICollectionViewCell, _ indexPath: IndexPath) -> ())?

    /// A callback sent when the user selects a value from the collection view.
    public var didSelectValue: ((_ cell: UICollectionViewCell?, _ value: ValueDisplay.Value) -> ())?

    /// A callback sent when the user scrolls the collection view.
    public var didScroll: ((_ offset: CGPoint) -> ())?
}

extension ArrayLoaderCollectionViewController
{
    fileprivate func updateCollectionViewProducer(for event: LoaderEvent<ValueDisplay.Value, ErrorDisplay.Error>)
        -> SignalProducer<(), NoError>
    {
        return SignalProducer { [weak self] observer, disposable in
            guard let strong = self else { return observer.sendCompleted() }

            // update the local loader state - the collection view data source methods will reference this
            strong.arrayLoaderState = event.state

            switch event
            {
            case .current:
                strong.collectionView.reloadData()
                observer.sendCompleted()

            case .nextPageLoading:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.nextPageActivity, .nextPageError])
                    .start(observer)

            case .previousPageLoading:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.previousPageActivity, .previousPageError])
                    .start(observer)

            case let .nextPageLoaded(state, _, newElements):
                disposable += strong.collectionView
                    .updateForPageLoadedEventProducer(
                        sections: [.nextPageActivity, .nextPageCompleted],
                        indexPaths: (state.elements.count - newElements.count..<state.elements.count).map({ item in
                            IndexPath(item: item, section: Section.values.rawValue)
                        })
                    )
                    .start(observer)

            case let .previousPageLoaded(_, _, newElements):
                disposable += strong.collectionView
                    .updateForPageLoadedEventProducer(
                        sections: [.previousPageActivity],
                        indexPaths: (0..<newElements.count).map({ item in
                            IndexPath(item: item, section: Section.values.rawValue)
                        })
                    )
                    .start(observer)

            case .nextPageFailed:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.nextPageActivity, .nextPageError])
                    .start(observer)

            case .previousPageFailed:
                disposable += strong.collectionView
                    .updateForPageLoadingEventProducer(sections: [.previousPageActivity, .previousPageError])
                    .start(observer)
            }
        }
    }
}

// MARK: - Previous Page Loading

/// Describes the previous page loading methods for `ArrayLoaderCollectionViewController`.
public enum PreviousPageLoadingMode<Value, Error: Swift.Error>
{
    /// Loading the previous page is disallowed.
    case disallow

    /// The array loader's `loadPreviousPage` method will be called.
    case loadPreviousPage(title: String)

    /// A new array loader will replace the current array loader.
    case replace(title: String, replacement: () -> AnyArrayLoader<Value, Error>)
}

extension PreviousPageLoadingMode
{
    var isLoadPreviousPage: Bool
    {
        switch self
        {
        case .disallow:
            return false
        case .loadPreviousPage:
            return true
        case .replace:
            return false
        }
    }

    var isReplace: Bool
    {
        switch self
        {
        case .disallow:
            return false
        case .loadPreviousPage:
            return false
        case .replace:
            return true
        }
    }

    var title: String?
    {
        switch self
        {
        case .disallow:
            return nil
        case let .loadPreviousPage(title):
            return title
        case let .replace(title, _):
            return title
        }
    }
}

// MARK: - Collection View Updates
extension UICollectionView
{
    fileprivate func batchUpdatesProducer(_ updates: @escaping () -> ()) -> SignalProducer<(), NoError>
    {
        return SignalProducer { observer, _ in
            self.performBatchUpdates(updates, completion: { _ in observer.sendCompleted() })
        }
    }

    fileprivate func reload(sections: [Section])
    {
        let set = NSMutableIndexSet()
        sections.forEach({ set.add($0.rawValue) })
        reloadSections(set as IndexSet)
    }

    fileprivate func updateForPageLoadingEventProducer(sections: [Section]) -> SignalProducer<(), NoError>
    {
        return batchUpdatesProducer { self.reload(sections: sections) }
    }

    fileprivate func updateForPageLoadedEventProducer(sections: [Section], indexPaths: [IndexPath])
        -> SignalProducer<(), NoError>
    {
        return batchUpdatesProducer {
            self.reload(sections: sections)
            self.insertItems(at: indexPaths)
        }
    }
}
