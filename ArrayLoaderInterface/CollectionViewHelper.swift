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
    <ValueDisplay: ValueDisplayType,
     ErrorDisplay: ErrorDisplayType,
     ActivityDisplay,
     PullDisplay: PullDisplayType,
     CompletedDisplay
     where ValueDisplay: UICollectionViewCell,
           ErrorDisplay: UICollectionViewCell,
           ActivityDisplay: UICollectionViewCell,
           PullDisplay: UICollectionViewCell,
           CompletedDisplay: UICollectionViewCell
    >
    : NSObject, UICollectionViewDataSource, UICollectionViewDelegate
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
    @objc func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int
    {
        return Section.NextPageCompleted.rawValue + 1
    }

    @objc func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let arrayLoader = parent.arrayLoader.value

        switch Section(rawValue: section)!
        {
        case .PreviousPagePull:
            return arrayLoader.previousPageState.value == .HasMore && parent.allowLoadingPreviousPage.value ? 1 : 0

        case .PreviousPageActivity:
            return arrayLoader.previousPageState.value == .Loading ? 1 : 0

        case .PreviousPageError:
            return arrayLoader.previousPageState.value.error != nil ? 1 : 0

        case .CustomHeaderView:
            return parent.customHeaderView != nil ? 1 : 0

        case .Values:
            return arrayLoader.state.value.elements.count

        case .NextPageActivity:
            let state = arrayLoader.nextPageState.value
            return state == .HasMore || state == .Loading ? 1 : 0

        case .NextPageError:
            return arrayLoader.nextPageState.value.error != nil ? 1 : 0

        case .NextPageCompleted:
            return arrayLoader.nextPageState.value == .Completed ? 1 : 0
        }
    }

    @objc func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath)
        -> UICollectionViewCell
    {
        switch Section(rawValue: indexPath.section)!
        {
        case .PreviousPagePull:
            return collectionView.dequeue(PullDisplay.self, forIndexPath: indexPath)

        case .PreviousPageActivity:
            return collectionView.dequeue(ActivityDisplay.self, forIndexPath: indexPath)

        case .PreviousPageError:
            let cell = collectionView.dequeue(ErrorDisplay.self, forIndexPath: indexPath)
            cell.error = parent.arrayLoader.value.previousPageState.value.error
            return cell

        case .CustomHeaderView:
            let cell = collectionView.dequeue(CustomHeaderViewCollectionViewCell.self, forIndexPath: indexPath)

            if let view = parent.customHeaderView
            {
                // remove from any other cell this view is in
                view.removeFromSuperview()

                // add the view to the new cell
                cell.contentView.addSubview(view)
                cell.addConstraints([NSLayoutAttribute.Leading, .Trailing, .Top, .Bottom].map({ attribute in
                    NSLayoutConstraint(
                        item: view,
                        attribute: attribute,
                        relatedBy: .Equal,
                        toItem: cell.contentView,
                        attribute: attribute,
                        multiplier: 1,
                        constant: 0
                    )
                }))
            }

            return cell

        case .Values:
            let cell = collectionView.dequeue(ValueDisplay.self, forIndexPath: indexPath)
            cell.value = parent.arrayLoader.value.state.value.elements[indexPath.item]
            return cell

        case .NextPageActivity:
            return collectionView.dequeue(ActivityDisplay.self, forIndexPath: indexPath)

        case .NextPageError:
            let cell = collectionView.dequeue(ErrorDisplay.self, forIndexPath: indexPath)
            cell.error = parent.arrayLoader.value.previousPageState.value.error
            return cell

        case .NextPageCompleted:
            return collectionView.dequeue(CompletedDisplay.self, forIndexPath: indexPath)
        }
    }

    // MARK: - Collection View Delegate
    @objc func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        parent.didSelectValue?(parent.arrayLoader.value.state.value.elements[indexPath.item])
    }
    
    @objc func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool
    {
        return Section(rawValue: indexPath.section)! == .Values
    }
    
    @objc func scrollViewDidScroll(scrollView: UIScrollView)
    {
        if (parent.arrayLoader.value.nextPageState.value.isHasMore ?? false)
            && parent.collectionView.indexPathsForVisibleItems().reduce(false, combine: { current, path in
                current || path.section == Section.NextPageActivity.rawValue
            })
        {
            parent.arrayLoader.value.loadNextPage()
        }
    }
}
