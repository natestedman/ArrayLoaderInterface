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
import UIKit

/// Hides the implementation of collection view protocols to clients.
internal final class CollectionViewHelper
    <ValueDisplay: ArrayLoaderValueDisplaying,
     ErrorDisplay: ArrayLoaderErrorDisplaying,
     ActivityDisplay,
     PullDisplay: ArrayLoaderPullToRefreshDisplaying,
     CompletedDisplay>
    : NSObject, UICollectionViewDataSource, UICollectionViewDelegate
     where ValueDisplay: UICollectionViewCell,
           ErrorDisplay: UICollectionViewCell,
           ActivityDisplay: UICollectionViewCell,
           PullDisplay: UICollectionViewCell,
           CompletedDisplay: UICollectionViewCell
    
{
    /// The type of the parent controller.
    typealias Parent =
        ArrayLoaderCollectionViewController<ValueDisplay, ErrorDisplay, ActivityDisplay, PullDisplay, CompletedDisplay>

    /// The parent controller associated with this helper.
    unowned let parent: Parent

    /**
     Initializes a helper object.

     - parameter parent: The parent controller to associate with this helper.
     */
    init(parent: Parent)
    {
        self.parent = parent
    }

    // MARK: - Collection View Data Source
    @objc func numberOfSections(in collectionView: UICollectionView) -> Int
    {
        return Section.nextPageCompleted.rawValue + 1
    }

    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let state = parent.arrayLoaderState

        switch Section(rawValue: section)!
        {
        case .previousPagePull:
            let mode = parent.previousPageLoadingMode.value
            return (state.previousPageState == .hasMore && mode.isLoadPreviousPage) || mode.isReplace ? 1 : 0

        case .previousPageActivity:
            return state.previousPageState == .loading ? 1 : 0

        case .previousPageError:
            return state.previousPageState.error != nil ? 1 : 0

        case .customHeaderView:
            return parent.customHeaderView != nil ? 1 : 0

        case .values:
            return state.elements.count

        case .nextPageActivity:
            let state = state.nextPageState
            return state == .hasMore || state == .loading ? 1 : 0

        case .nextPageError:
            return state.nextPageState.error != nil ? 1 : 0

        case .nextPageCompleted:
            return state.nextPageState == .completed ? 1 : 0
        }
    }

    @objc func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell
    {
        switch Section(rawValue: indexPath.section)!
        {
        case .previousPagePull:
            return collectionView.dequeue(PullDisplay.self, forIndexPath: indexPath)

        case .previousPageActivity:
            return collectionView.dequeue(ActivityDisplay.self, forIndexPath: indexPath)

        case .previousPageError:
            let cell = collectionView.dequeue(ErrorDisplay.self, forIndexPath: indexPath)
            cell.error = parent.arrayLoaderState.previousPageState.error
            return cell

        case .customHeaderView:
            let cell = collectionView.dequeue(CustomHeaderViewCollectionViewCell.self, forIndexPath: indexPath)

            if let view = parent.customHeaderView
            {
                // remove from any other cell this view is in
                view.removeFromSuperview()

                // add the view to the new cell
                cell.contentView.addSubview(view)
                cell.addConstraints([NSLayoutAttribute.leading, .trailing, .top, .bottom].map({ attribute in
                    NSLayoutConstraint(
                        item: view,
                        attribute: attribute,
                        relatedBy: .equal,
                        toItem: cell.contentView,
                        attribute: attribute,
                        multiplier: 1,
                        constant: 0
                    )
                }))
            }

            return cell

        case .values:
            let cell = collectionView.dequeue(ValueDisplay.self, forIndexPath: indexPath)
            cell.value = parent.arrayLoaderState.elements[indexPath.item]
            return cell

        case .nextPageActivity:
            return collectionView.dequeue(ActivityDisplay.self, forIndexPath: indexPath)

        case .nextPageError:
            let cell = collectionView.dequeue(ErrorDisplay.self, forIndexPath: indexPath)
            cell.error = parent.arrayLoaderState.previousPageState.error
            return cell

        case .nextPageCompleted:
            return collectionView.dequeue(CompletedDisplay.self, forIndexPath: indexPath)
        }
    }

    // MARK: - Collection View Delegate
    @objc func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        parent.willDisplayCell?(cell, indexPath)
    }

    @objc func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        parent.didSelectValue?(
            collectionView.cellForItem(at: indexPath),
            parent.arrayLoaderState.elements[indexPath.item]
        )
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool
    {
        return Section(rawValue: indexPath.section)! == .values
    }
    
    @objc func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        if parent.arrayLoader.value.nextPageState.isHasMore
            && parent.collectionView.indexPathsForVisibleItems.reduce(false, { current, path in
                current || path.section == Section.nextPageActivity.rawValue
            })
        {
            parent.arrayLoader.value.loadNextPage()
        }

        parent.didScroll?(scrollView.contentOffset)
    }
}
